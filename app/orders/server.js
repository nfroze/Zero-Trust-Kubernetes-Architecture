const http = require("http");

const PORT = process.env.PORT || 3000;
const DATABASE_URL =
  process.env.DATABASE_URL || "http://database.data.svc.cluster.local";

const server = http.createServer(async (req, res) => {
  res.setHeader("Content-Type", "application/json");

  if (req.url === "/health") {
    res.writeHead(200);
    res.end(JSON.stringify({ status: "healthy", service: "orders" }));
    return;
  }

  if (req.url === "/orders" && req.method === "GET") {
    try {
      const dbResponse = await fetch(`${DATABASE_URL}/query?table=orders`);
      const dbData = await dbResponse.json();
      res.writeHead(200);
      res.end(
        JSON.stringify({
          service: "orders",
          data: dbData,
        })
      );
    } catch (err) {
      res.writeHead(502);
      res.end(
        JSON.stringify({
          service: "orders",
          error: "Database unreachable",
          detail: err.message,
        })
      );
    }
    return;
  }

  if (req.url === "/orders" && req.method === "POST") {
    try {
      const dbResponse = await fetch(`${DATABASE_URL}/mutate`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ table: "orders", action: "insert" }),
      });
      const dbData = await dbResponse.json();
      res.writeHead(201);
      res.end(
        JSON.stringify({
          service: "orders",
          action: "created",
          data: dbData,
        })
      );
    } catch (err) {
      res.writeHead(502);
      res.end(
        JSON.stringify({
          service: "orders",
          error: "Database unreachable",
          detail: err.message,
        })
      );
    }
    return;
  }

  res.writeHead(404);
  res.end(JSON.stringify({ error: "Not found" }));
});

server.listen(PORT, () => {
  console.log(`orders service listening on port ${PORT}`);
});
