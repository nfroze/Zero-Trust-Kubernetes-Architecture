const http = require("http");

const PORT = process.env.PORT || 3000;
const API_GATEWAY_URL =
  process.env.API_GATEWAY_URL || "http://api-gateway.backend.svc.cluster.local";

const server = http.createServer(async (req, res) => {
  res.setHeader("Content-Type", "application/json");

  if (req.url === "/health") {
    res.writeHead(200);
    res.end(JSON.stringify({ status: "healthy", service: "frontend" }));
    return;
  }

  if (req.url === "/") {
    try {
      const response = await fetch(`${API_GATEWAY_URL}/api/orders`);
      const data = await response.json();
      res.writeHead(200);
      res.end(
        JSON.stringify({
          service: "frontend",
          message: "Zero Trust Demo — Frontend",
          upstream: data,
        })
      );
    } catch (err) {
      res.writeHead(502);
      res.end(
        JSON.stringify({
          service: "frontend",
          error: "Failed to reach api-gateway",
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
  console.log(`frontend listening on port ${PORT}`);
});
