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

    // Streaming text stays plain so half a fence never renders as a broken block.
    // It becomes markdown once the message is complete.
    function paint(node, message) {
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

    window.piui = {
        render: function (messages) {
            var stick = pinnedToBottom();
            var seen = {};

            messages.forEach(function (message) {
                seen[message.id] = true;
                var node = element(message);
                var signature = message.text.length + "|" + message.done;
                if (node.dataset.signature !== signature) {
                    node.dataset.signature = signature;
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
