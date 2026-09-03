export function rpc(endpoint, method, params = [], timeoutMs = 20_000) {
  return new Promise((resolve, reject) => {
    const socket = new WebSocket(endpoint);
    const timer = setTimeout(() => {
      socket.close();
      reject(new Error(`${method} timed out at ${endpoint}`));
    }, timeoutMs);

    socket.addEventListener("open", () => {
      socket.send(JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }));
    });
    socket.addEventListener("message", ({ data }) => {
      const message = JSON.parse(data.toString());
      if (message.id !== 1) return;
      clearTimeout(timer);
      socket.close();
      if (message.error) reject(new Error(JSON.stringify(message.error)));
      else resolve(message.result);
    });
    socket.addEventListener("error", () => {
      clearTimeout(timer);
      reject(new Error(`WebSocket failure at ${endpoint}`));
    });
  });
}

export async function waitForRpc(endpoint, timeoutMs = 300_000) {
  const deadline = Date.now() + timeoutMs;
  let lastError;

  while (Date.now() < deadline) {
    const remaining = deadline - Date.now();
    try {
      await rpc(endpoint, "system_health", [], Math.min(10_000, remaining));
      return;
    } catch (error) {
      lastError = error;
      await new Promise((resolve) => setTimeout(resolve, Math.min(2_000, remaining)));
    }
  }

  throw new Error(
    `RPC did not become ready at ${endpoint} within ${Math.round(timeoutMs / 1_000)}s` +
      (lastError ? `: ${lastError.message}` : ""),
  );
}

export function hexBlockNumber(header) {
  return Number.parseInt(header.number, 16);
}
