const http = require("http");

const PORT = process.env.PORT || 3000;
const ORDERS_URL =
  process.env.ORDERS_URL || "http://orders.backend.svc.cluster.local";
const AUTH_URL =
  process.env.AUTH_URL || "http://auth.backend.svc.cluster.local";

async function callService(url) {
  const response = await fetch(url);
  return response.json();
}

const server = http.createServer(async (req, res) => {
  res.setHeader("Content-Type", "application/json");

  if (req.url === "/health") {
    res.writeHead(200);
    res.end(JSON.stringify({ status: "healthy", service: "api-gateway" }));
    return;
  }

  if (req.url === "/api/orders" && req.method === "GET") {
    try {
      const [authResult, ordersResult] = await Promise.all([
        callService(`${AUTH_URL}/verify`),
        callService(`${ORDERS_URL}/orders`),
      ]);
      res.writeHead(200);
      res.end(
        JSON.stringify({
          service: "api-gateway",
          auth: authResult,
          orders: ordersResult,
        })
      );
    } catch (err) {
      res.writeHead(502);
      res.end(
        JSON.stringify({
          service: "api-gateway",
          error: "Upstream service failure",
          detail: err.message,
        })
      );
    }
    return;
  }

  if (req.url === "/api/auth/verify" && req.method === "GET") {
    try {
      const authResult = await callService(`${AUTH_URL}/verify`);
      res.writeHead(200);
      res.end(
        JSON.stringify({ service: "api-gateway", auth: authResult })
      );
    } catch (err) {
      res.writeHead(502);
      res.end(
        JSON.stringify({
          service: "api-gateway",
          error: "Auth service unreachable",
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
  console.log(`api-gateway listening on port ${PORT}`);
});
