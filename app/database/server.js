const http = require("http");
const url = require("url");

const PORT = process.env.PORT || 3000;

// In-memory mock data store — simulates a database for demo purposes.
// In production this would be replaced with an actual database.
const store = {
  orders: [
    { id: 1, item: "Widget A", quantity: 3, status: "shipped" },
    { id: 2, item: "Widget B", quantity: 1, status: "processing" },
    { id: 3, item: "Gadget C", quantity: 5, status: "delivered" },
  ],
  users: [
    { id: 1, name: "alice", role: "admin" },
    { id: 2, name: "bob", role: "viewer" },
  ],
};

const server = http.createServer((req, res) => {
  res.setHeader("Content-Type", "application/json");
  const parsed = url.parse(req.url, true);

  if (parsed.pathname === "/health") {
    res.writeHead(200);
    res.end(JSON.stringify({ status: "healthy", service: "database" }));
    return;
  }

  if (parsed.pathname === "/query" && req.method === "GET") {
    const table = parsed.query.table;
    if (!table || !store[table]) {
      res.writeHead(400);
      res.end(JSON.stringify({ error: "Invalid table", available: Object.keys(store) }));
      return;
    }
    res.writeHead(200);
    res.end(
      JSON.stringify({
        service: "database",
        table: table,
        count: store[table].length,
        records: store[table],
      })
    );
    return;
  }

  if (parsed.pathname === "/mutate" && req.method === "POST") {
    let body = "";
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => {
      try {
        const payload = JSON.parse(body);
        const table = payload.table;
        if (!table || !store[table]) {
          res.writeHead(400);
          res.end(JSON.stringify({ error: "Invalid table" }));
          return;
        }
        const newRecord = {
          id: store[table].length + 1,
          ...payload.data,
          created: new Date().toISOString(),
        };
        store[table].push(newRecord);
        res.writeHead(201);
        res.end(
          JSON.stringify({
            service: "database",
            action: "inserted",
            record: newRecord,
          })
        );
      } catch (err) {
        res.writeHead(400);
        res.end(JSON.stringify({ error: "Invalid JSON" }));
      }
    });
    return;
  }

  res.writeHead(404);
  res.end(JSON.stringify({ error: "Not found" }));
});

server.listen(PORT, () => {
  console.log(`database service listening on port ${PORT}`);
});
