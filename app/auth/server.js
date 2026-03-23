const http = require("http");

const PORT = process.env.PORT || 3000;
const DATABASE_URL =
  process.env.DATABASE_URL || "http://database.data.svc.cluster.local";

const server = http.createServer(async (req, res) => {
  res.setHeader("Content-Type", "application/json");

  if (req.url === "/health") {
    res.writeHead(200);
    res.end(JSON.stringify({ status: "healthy", service: "auth" }));
    return;
  }

  if (req.url === "/verify" && req.method === "GET") {
    try {
      const dbResponse = await fetch(`${DATABASE_URL}/query?table=users`);
      const dbData = await dbResponse.json();
      res.writeHead(200);
      res.end(
        JSON.stringify({
          service: "auth",
          verified: true,
          userCount: dbData.count || 0,
        })
      );
    } catch (err) {
      res.writeHead(502);
      res.end(
        JSON.stringify({
          service: "auth",
          verified: false,
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
  console.log(`auth service listening on port ${PORT}`);
});
