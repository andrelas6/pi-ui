(function () {
    "use strict";

    marked.setOptions({ gfm: true, breaks: false });

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
            '<pre class="out"></pre>';
        node.appendChild(card);
        return card;
    }

    function paintTool(node, message) {
        var card = node.firstChild || buildCard(node);
        var tool = message.tool || {};

        card.querySelector(".name").textContent = tool.name || "";
        card.querySelector(".preview").textContent = tool.preview || "";
        card.querySelector(".args").textContent = tool.arguments || "";

        var out = card.querySelector(".out");
        out.textContent = tool.output || "";
        out.style.display = tool.output ? "" : "none";

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
