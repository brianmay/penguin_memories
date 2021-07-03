// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import "../css/app.scss";

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import deps with the dep name or local files with a relative path, for example:
//
//     import {Socket} from "phoenix"
//     import socket from "./socket"
//
import "bootstrap";

let metadata  = {
    click: (e, el) => {
        console.log(e);
        return {
            shiftKey: e.shiftKey,
            ctrlKey: e.ctrlKey,
            altKey: e.altKey,
            clientX: e.clientX,
            clientY: e.clientY
        };
    }
}
import "phoenix_html";
import {Socket} from "phoenix";
import NProgress from "nprogress";
import {LiveSocket} from "phoenix_live_view";

function get_video(node) {
    let parent = node.parentNode; // gives the parent DIV
    let children = parent.childNodes;
    let result = null;
    for (var i=0; i < children.length; i++) {
        if (children[i].tagName == "VIDEO") {
            result = children[i];
            break;
        }
    }
    return result;
}

let Hooks = {};
Hooks.video = {
    mounted() {
        this.updated()
    },

    updated() {
        let video = get_video(this.el);
        let children = this.el.children;
        for (let i = 0; i < children.length; i++) {
            let child = children[i];
            let current_src = this.el.getAttribute("src");
            let src = child.getAttribute("src");
            let type = child.getAttribute("type");
            if (video.canPlayType(type) && src != current_src) {
                video.setAttribute("src", src);
                break
            }
        }

    }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, metadata: metadata, hooks: Hooks});

// Show progress bar on live navigation and form submits
window.addEventListener("phx:page-loading-start", info => NProgress.start());
window.addEventListener("phx:page-loading-stop", info => NProgress.done());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
