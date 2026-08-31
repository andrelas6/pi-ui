// pi ships no permission prompts by design. This asks before anything that can
// change the machine, and blocks it when the answer is no.

const guarded = new Set(["bash", "powershell", "write", "edit", "multi_edit"]);

function describe(event) {
    const input = event.input || {};
    for (const key of ["command", "path", "file_path", "pattern"]) {
        if (typeof input[key] === "string" && input[key]) return input[key];
    }
    return JSON.stringify(input).slice(0, 400);
}

export default function (pi) {
    pi.on("tool_call", async (event, ctx) => {
        if (!guarded.has(event.toolName)) return undefined;

        if (!ctx.hasUI) {
            return { block: true, reason: "No UI available to approve this" };
        }

        // The title is the bare tool name so the app can match a remembered answer
        // against it. The app writes the question the reader sees.
        const allowed = await ctx.ui.confirm(event.toolName, describe(event));
        if (!allowed) {
            return { block: true, reason: "Denied by the user" };
        }
        return undefined;
    });
}
