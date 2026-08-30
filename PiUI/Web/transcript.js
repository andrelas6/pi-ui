(function () {
    "use strict";

    marked.setOptions({ gfm: true, breaks: false });

    // Auto-detection is only worth it on a block big enough to guess from.
    var GUESS_LIMIT = 20000;

    function paintCode(root) {
        root.querySelectorAll("pre code").forEach(function (block) {
            if (block.dataset.lit) return;
            block.dataset.lit = "1";

            var code = block.textContent || "";
            if (!code || code.length > GUESS_LIMIT) return;

            var named = (block.className.match(/language-([\w+#-]+)/) || [])[1];
            try {
                var result = named && hljs.getLanguage(named)
                    ? hljs.highlight(code, { language: named })
                    : hljs.highlightAuto(code);
                block.innerHTML = result.value;
                block.classList.add("hljs");
            } catch (ignored) {
                // A block we cannot parse reads fine unhighlighted.
            }
        });
    }

    var log = document.getElementById("log");
    var nodes = {};

    function pinnedToBottom() {
        return window.innerHeight + window.scrollY >= document.body.scrollHeight - 40;
    }

    function element(message) {
        var node = nodes[message.id];
        if (!node) {
            node = document.createElement("div");
            node.id = "m-" + message.id;
            log.appendChild(node);
            nodes[message.id] = node;
        }
        return node;
    }

    function buildCard(node) {
        var card = document.createElement("details");
        card.className = "card";
        card.open = true;
        card.innerHTML =
            '<summary>' +
            '<span class="name"></span>' +
            '<span class="preview"></span>' +
            '<span class="state"></span>' +
            "</summary>" +
            '<pre class="args"></pre>' +
            '<pre class="diff"></pre>' +
            '<pre class="out"></pre>';
        node.appendChild(card);
        return card;
    }

    function paintTool(node, message) {
        var card = node.firstChild || buildCard(node);
        var tool = message.tool || {};

        card.querySelector(".name").textContent = tool.name || "";
        card.querySelector(".preview").textContent = tool.preview || "";
        // A diff says everything the raw edit arguments would, and says it better.
        var diff = card.querySelector(".diff");
        var args = card.querySelector(".args");
        if (tool.diff) {
            diff.innerHTML = "";
            tool.diff.split("\n").forEach(function (line) {
                var row = document.createElement("span");
                var mark = line.charAt(0);
                row.className = "row " + (mark === "+" ? "add" : mark === "-" ? "del" : "same");
                row.textContent = line;
                diff.appendChild(row);
            });
            diff.style.display = "";
            args.style.display = "none";
        } else {
            diff.style.display = "none";
            args.textContent = tool.arguments || "";
            args.style.display = "";
        }

        var out = card.querySelector(".out");
        out.textContent = tool.output || "";
        out.style.display = tool.output && !tool.diff ? "" : "none";

        var state = card.querySelector(".state");
        if (!message.done) {
            state.textContent = "running";
            state.className = "state running";
        } else if (tool.failed) {
            state.textContent = "failed";
            state.className = "state failed";
        } else {
            state.textContent = "done";
            state.className = "state done";
        }

        card.classList.toggle("is-failed", !!tool.failed);
    }

    // Streaming text stays plain so half a fence never renders as a broken block.
    // It becomes markdown once the message is complete.
    function paint(node, message) {
        if (message.kind === "tool") {
            node.className = "msg tool";
            paintTool(node, message);
            return;
        }

        var streaming = message.kind === "assistant" && !message.done;
        node.className = "msg " + message.kind + (streaming ? " streaming" : "");

        if (message.kind === "assistant" && message.done) {
            node.innerHTML = marked.parse(message.text || "");
            paintCode(node);
            return;
        }

        node.textContent = message.text || "";
        if (streaming) {
            node.appendChild(document.createElement("span")).className = "cursor";
        }
    }

    function signature(message) {
        if (message.kind === "tool") {
            var tool = message.tool || {};
            return [
                tool.name,
                tool.preview,
                (tool.arguments || "").length,
                (tool.output || "").length,
                (tool.diff || "").length,
                tool.failed,
                message.done
            ].join("|");
        }
        return message.text.length + "|" + message.done;
    }

    window.piui = {
        render: function (messages) {
            var stick = pinnedToBottom();
            var seen = {};

            messages.forEach(function (message) {
                seen[message.id] = true;
                var node = element(message);
                var next = signature(message);
                if (node.dataset.signature !== next) {
                    node.dataset.signature = next;
                    paint(node, message);
                }
            });

            Object.keys(nodes).forEach(function (id) {
                if (!seen[id]) {
                    nodes[id].remove();
                    delete nodes[id];
                }
            });

            if (stick) {
                window.scrollTo(0, document.body.scrollHeight);
            }
        }
    };

    document.addEventListener("click", function (event) {
        var link = event.target.closest("a");
        if (link && link.href) {
            event.preventDefault();
            window.webkit.messageHandlers.openLink.postMessage(link.href);
        }
    });
})();
