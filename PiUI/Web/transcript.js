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
            '<summary class="call">' +
            '<span class="name"></span>' +
            '<span class="preview"></span>' +
            '<span class="result"></span>' +
            '<span class="state"></span>' +
            "</summary>" +
            '<pre class="args"></pre>' +
            '<div class="diff">' +
            '<i class="corner tl"></i><i class="corner tr"></i>' +
            '<i class="corner bl"></i><i class="corner br"></i>' +
            '<div class="strip"></div><div class="lines"></div></div>' +
            '<pre class="out"></pre>';
        node.appendChild(card);
        return card;
    }

    function paintTool(node, message) {
        var card = node.firstChild || buildCard(node);
        var tool = message.tool || {};

        card.querySelector(".name").textContent = tool.name || "";
        card.querySelector(".preview").textContent = tool.preview || "";
        card.querySelector(".result").textContent = tool.result || "";
        // A diff says everything the raw edit arguments would, and says it better.
        var diff = card.querySelector(".diff");
        var args = card.querySelector(".args");
        if (tool.diff) {
            diff.querySelector(".strip").textContent = tool.preview || "";
            var lines = diff.querySelector(".lines");
            lines.innerHTML = "";
            tool.diff.split("\n").forEach(function (line) {
                var row = document.createElement("span");
                var mark = line.charAt(0);
                row.className = "row " + (mark === "+" ? "add" : mark === "-" ? "del" : "same");
                row.textContent = line;
                lines.appendChild(row);
            });
            diff.style.display = "";
            args.style.display = "none";
        } else {
            diff.style.display = "none";
            args.textContent = tool.arguments || "";
            // An announced call whose arguments have not arrived yet has nothing to show.
            args.style.display = tool.arguments ? "" : "none";
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
    function kicker(node, message) {
        var label = node.querySelector(".kicker");
        if (!label) {
            label = document.createElement("div");
            label.className = "kicker";
            node.appendChild(label);
        }
        label.textContent = message.kicker || "";
        label.style.display = message.kicker ? "" : "none";
        return label;
    }

    function bodyOf(node, className) {
        var body = node.querySelector("." + className);
        if (!body) {
            body = document.createElement("div");
            body.className = className;
            node.appendChild(body);
        }
        return body;
    }

    function paintPermission(node, message) {
        var request = message.request || {};
        node.className = "msg permission";
        node.innerHTML =
            '<div class="ask">' +
            '<i class="corner tl"></i><i class="corner tr"></i>' +
            '<i class="corner bl"></i><i class="corner br"></i>' +
            '<div class="head"><span class="dot"></span><span class="label"></span></div>' +
            '<div class="detail">Allow <code class="tool"></code> to run <code class="cmd"></code>?</div>' +
            '<div class="choices"></div>' +
            "</div>";

        node.querySelector(".label").textContent = message.kicker || "permission requested";
        node.querySelector(".tool").textContent = request.tool || "";
        node.querySelector(".cmd").textContent = request.detail || "";

        var choices = node.querySelector(".choices");
        if (message.done) {
            var settled = document.createElement("span");
            settled.className = "settled";
            settled.textContent = request.answer === "deny" ? "denied"
                : request.answer === "always" ? "always allowed"
                : request.answer === "allow" ? "allowed"
                : "no longer waiting";
            choices.appendChild(settled);
            return;
        }

        [
            { key: "allow", label: "Allow once", kind: "primary" },
            { key: "always", label: "Always allow", kind: "secondary" },
            { key: "deny", label: "Deny", kind: "ghost" }
        ].forEach(function (choice) {
            var button = document.createElement("button");
            button.className = "choice " + choice.kind;
            button.textContent = choice.label;
            button.addEventListener("click", function () {
                window.webkit.messageHandlers.permission.postMessage({
                    id: message.id,
                    choice: choice.key
                });
            });
            choices.appendChild(button);
        });

        var hint = document.createElement("span");
        hint.className = "hint";
        hint.textContent = "⌘Y allow · ⇧⌘Y always · ⌘R deny";
        choices.appendChild(hint);
    }

    function paint(node, message) {
        if (message.kind === "permission") {
            paintPermission(node, message);
            return;
        }

        if (message.kind === "tool") {
            node.className = "msg tool";
            paintTool(node, message);
            return;
        }

        node.className = "msg " + (message.kind === "user" ? "user" : "agent");
        kicker(node, message);

        if (message.kind === "user") {
            bodyOf(node, "body").textContent = message.text || "";
            return;
        }

        var prose = bodyOf(node, "prose");
        var streaming = !message.done;
        prose.className = "prose" + (streaming ? " streaming" : "");

        if (!streaming) {
            prose.innerHTML = marked.parse(message.text || "");
            paintCode(prose);
            return;
        }

        prose.textContent = message.text || "";
        prose.appendChild(document.createElement("span")).className = "cursor";
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
                tool.result,
                tool.failed,
                message.done
            ].join("|");
        }
        if (message.kind === "permission") {
            var request = message.request || {};
            return [request.tool, request.detail, request.answer, message.done].join("|");
        }
        return [message.text.length, message.done, message.kicker].join("|");
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
