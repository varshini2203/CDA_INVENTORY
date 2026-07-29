// functions/index.js
//
// Callable Cloud Function backing the AI Assistant. The OpenAI API key
// lives ONLY here (as a Firebase secret) — it is never sent to, or
// reachable from, the Flutter client. The client calls `aiAssistant` via
// FirebaseFunctions.instance.httpsCallable('aiAssistant'), same callable
// pattern as any other Cloud Function in a Firebase app (no new auth
// mechanism, reuses the caller's existing Firebase Auth session).
//
// Firestore is read here using firebase-admin (server-side, bypasses
// security rules — appropriate since this only ever runs for an
// authenticated caller and only ever reads, never writes). This does
// NOT change any existing Firestore structure, security rules, or
// client-side service — it's a new, separate read path.

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const OpenAI = require('openai');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

const OPENAI_API_KEY = defineSecret('OPENAI_API_KEY');

// ── Routes the assistant is allowed to send the user to. Kept in sync by
// hand with lib/main.dart's `routes` table — intentionally NOT every
// screen in the app, only the ones reachable by a named route, since the
// requirement is "don't modify existing routes." ─────────────────────────
const NAVIGABLE_SCREENS = {
  dashboard: '/dashboard',
  inventory: '/inventory',
  bills: '/bills',
  admin_notifications: '/admin/notifications',
  admin_employees: '/admin/employees',
  admin_activity: '/admin/activity',
};

const SYSTEM_PROMPT = `You are the AI Assistant embedded in CDA Inventory, an inventory/operations app for a drone academy (Chennai Drone Academy). You help staff with:
- Explaining what a screen or feature does and how to use it.
- Looking up real data (products/stock, invoices, drones, reports) using the tools provided — NEVER guess or invent numbers, always call a tool.
- Suggesting which screen to open for a task, using suggest_navigation.

App modules: Inventory/Stock, Products, Invoices/Bills, Purchases, Drone In/Out tracking with 1-hour return reminders, Fixed Assets, Consumables, Employees, Reports (monthly drone/stock/invoice summaries), Admin (notifications, employee access, activity feed).

Be concise and specific. If a user asks something outside this app's scope, say so briefly. If data isn't found, say so rather than guessing.`;

const TOOLS = [
  {
    type: 'function',
    function: {
      name: 'search_products',
      description: 'Search products/inventory by name or category. Returns matching products with quantity and price.',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string', description: 'Product name or category keyword to search for.' },
        },
        required: ['query'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'search_invoices',
      description: 'Search invoices by invoice number or customer name. Returns matching invoices with amount, status, and due date.',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string', description: 'Invoice number or customer name to search for.' },
        },
        required: ['query'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'search_drones',
      description: 'Search drones by name, serial number, or status. Returns matching drones with IN/OUT status, pilot, battery level, branch.',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string', description: 'Drone name, serial number, or status (IN/OUT) to search for.' },
        },
        required: ['query'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_monthly_report_summary',
      description: 'Get aggregated counts for a given month: drone in/out counts, stock in/out counts and quantities, invoice count and total.',
      parameters: {
        type: 'object',
        properties: {
          month: { type: 'integer', description: '1-12' },
          year: { type: 'integer', description: 'e.g. 2026' },
        },
        required: ['month', 'year'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'suggest_navigation',
      description: `Suggest navigating the user to a screen. Valid screen keys: ${Object.keys(NAVIGABLE_SCREENS).join(', ')}.`,
      parameters: {
        type: 'object',
        properties: {
          screen: { type: 'string', enum: Object.keys(NAVIGABLE_SCREENS) },
          reason: { type: 'string', description: 'One short sentence on why this screen helps.' },
        },
        required: ['screen'],
      },
    },
  },
];

async function searchProducts(query) {
  const snap = await db.collection('products').orderBy('name').limit(500).get();
  const q = query.toLowerCase();
  const matches = snap.docs
    .map((d) => d.data())
    .filter(
      (p) =>
        (p.name || '').toLowerCase().includes(q) ||
        (p.category || '').toLowerCase().includes(q)
    )
    .slice(0, 10)
    .map((p) => ({ name: p.name, category: p.category, quantity: p.quantity, price: p.price }));
  return { count: matches.length, matches };
}

async function searchInvoices(query) {
  const snap = await db.collection('invoices').limit(500).get();
  const q = query.toLowerCase();
  const matches = snap.docs
    .map((d) => d.data())
    .filter(
      (inv) =>
        (inv.invoiceNo || '').toLowerCase().includes(q) ||
        (inv.customer && (inv.customer.name || '').toLowerCase().includes(q)) ||
        (inv.vendorName || '').toLowerCase().includes(q)
    )
    .slice(0, 10)
    .map((inv) => ({
      invoiceNo: inv.invoiceNo,
      customer: inv.customer ? inv.customer.name : inv.vendorName,
      amount: inv.amount,
      status: inv.status,
      dueDate: inv.dueDate || null,
    }));
  return { count: matches.length, matches };
}

async function searchDrones(query) {
  const snap = await db.collection('drones').get();
  const q = query.toLowerCase();
  const matches = snap.docs
    .map((d) => d.data())
    .filter(
      (dr) =>
        (dr.name || '').toLowerCase().includes(q) ||
        (dr.serialNumber || '').toLowerCase().includes(q) ||
        (dr.status || '').toLowerCase() === q
    )
    .slice(0, 10)
    .map((dr) => ({
      name: dr.name,
      status: dr.status,
      pilotName: dr.pilotName || null,
      batteryLevel: dr.batteryLevel,
      branch: dr.branch || null,
    }));
  return { count: matches.length, matches };
}

async function getMonthlyReportSummary(month, year) {
  const start = new Date(year, month - 1, 1);
  const end = new Date(year, month, 1);
  const startTs = admin.firestore.Timestamp.fromDate(start);
  const endTs = admin.firestore.Timestamp.fromDate(end);

  const invoicesSnap = await db.collection('invoices').get();
  const invoicesInRange = invoicesSnap.docs
    .map((d) => d.data())
    .filter((inv) => {
      const created = inv.purchaseDate ? new Date(inv.purchaseDate) : null;
      return created && created >= start && created < end;
    });
  const invoiceCount = invoicesInRange.length;
  const invoiceTotal = invoicesInRange.reduce((sum, inv) => sum + (Number(inv.amount) || 0), 0);

  const dronesSnap = await db.collection('drones').get();
  let droneInCount = 0;
  let droneOutCount = 0;
  for (const doc of dronesSnap.docs) {
    const historySnap = await doc.ref
      .collection('history')
      .where('timestamp', '>=', startTs)
      .where('timestamp', '<', endTs)
      .get();
    for (const h of historySnap.docs) {
      const data = h.data();
      if (data.status === 'IN') droneInCount++;
      if (data.status === 'OUT') droneOutCount++;
    }
  }

  return {
    month,
    year,
    droneInCount,
    droneOutCount,
    invoiceCount,
    invoiceTotal,
  };
}

exports.aiAssistant = onCall(
  { secrets: [OPENAI_API_KEY], cors: true, timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }
    const { message, history } = request.data || {};
    if (!message || typeof message !== 'string') {
      throw new HttpsError('invalid-argument', 'message (string) is required.');
    }

    const openai = new OpenAI({ apiKey: OPENAI_API_KEY.value() });

    const messages = [
      { role: 'system', content: SYSTEM_PROMPT },
      ...(Array.isArray(history)
        ? history.slice(-10).map((m) => ({ role: m.role, content: m.content }))
        : []),
      { role: 'user', content: message },
    ];

    let navigateTo = null;
    let navigateReason = null;

    // Function-calling loop: at most 4 round trips, so a bad tool loop
    // can't run away with the caller's OpenAI quota.
    for (let i = 0; i < 4; i++) {
      const completion = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        messages,
        tools: TOOLS,
        tool_choice: 'auto',
      });

      const choice = completion.choices[0];
      const toolCalls = choice.message.tool_calls;

      if (!toolCalls || toolCalls.length === 0) {
        return {
          reply: choice.message.content || '',
          navigateTo,
          navigateReason,
        };
      }

      messages.push(choice.message);

      for (const call of toolCalls) {
        const args = JSON.parse(call.function.arguments || '{}');
        let result;
        try {
          switch (call.function.name) {
            case 'search_products':
              result = await searchProducts(args.query);
              break;
            case 'search_invoices':
              result = await searchInvoices(args.query);
              break;
            case 'search_drones':
              result = await searchDrones(args.query);
              break;
            case 'get_monthly_report_summary':
              result = await getMonthlyReportSummary(args.month, args.year);
              break;
            case 'suggest_navigation':
              if (NAVIGABLE_SCREENS[args.screen]) {
                navigateTo = NAVIGABLE_SCREENS[args.screen];
                navigateReason = args.reason || null;
              }
              result = { acknowledged: true };
              break;
            default:
              result = { error: `Unknown tool ${call.function.name}` };
          }
        } catch (err) {
          result = { error: String(err) };
        }
        messages.push({
          role: 'tool',
          tool_call_id: call.id,
          content: JSON.stringify(result),
        });
      }
    }

    return {
      reply: "I wasn't able to finish looking that up — could you rephrase or narrow the question?",
      navigateTo,
      navigateReason,
    };
  }
);