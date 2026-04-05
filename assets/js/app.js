// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import "../css/app.scss";

// Import Leaflet map library
import L from "leaflet";
import "leaflet/dist/leaflet.css";

// Fix for webpack marker icons
import markerIcon2x from 'leaflet/dist/images/marker-icon-2x.png';
import markerIcon from 'leaflet/dist/images/marker-icon.png';
import markerShadow from 'leaflet/dist/images/marker-shadow.png';

delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
    iconRetinaUrl: markerIcon2x,
    iconUrl: markerIcon,
    shadowUrl: markerShadow,
});

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
            button: e.button,
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

Hooks.map = {
    mounted() {
        const lat = parseFloat(this.el.dataset.lat);
        const lng = parseFloat(this.el.dataset.lng);
        
        if (isNaN(lat) || isNaN(lng)) {
            console.error("Invalid coordinates for map");
            return;
        }
        
        // Initialize global map instances storage
        if (!window.mapInstances) {
            window.mapInstances = {};
        }
        
        // Initialize the map
        this.map = L.map(this.el, {
            center: [lat, lng],
            zoom: 15,
            scrollWheelZoom: false
        });
        
        // Store map instance for toggle functionality
        window.mapInstances[this.el.id] = this.map;
        
        // Add OpenStreetMap tiles
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        }).addTo(this.map);
        
        // Add a marker at the photo location
        L.marker([lat, lng])
            .addTo(this.map)
            .bindPopup('Photo taken here')
            .openPopup();
    },
    
    destroyed() {
        if (this.map) {
            // Remove from global instances
            if (window.mapInstances && this.el.id) {
                delete window.mapInstances[this.el.id];
            }
            this.map.remove();
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

// Handle middle-click on icon links to open in new tab
document.addEventListener('mousedown', function(e) {
    // Only handle middle-click (button 1) on elements with phx-click that are also links
    if (e.button === 1 && e.target.closest('a[phx-click]')) {
        const link = e.target.closest('a[phx-click]');
        
        // Prevent the phx-click event from firing for middle-click
        e.stopImmediatePropagation();
        
        // Let the browser handle the middle-click naturally (open in new tab)
        // The href attribute will be used
        return true;
    }
});

// Handle left-clicks on icon links to prevent default navigation and allow phx-click
document.addEventListener('click', function(e) {
    // Only handle left-click (button 0) on elements with phx-click that are also links
    if (e.button === 0 && e.target.closest('a[phx-click]')) {
        const link = e.target.closest('a[phx-click]');
        
        // Prevent default navigation for left-clicks so phx-click can handle it
        e.preventDefault();
        
        // Let the phx-click event proceed normally
        return true;
    }
});

// Also handle auxiliary click events (middle-click, back/forward buttons)
document.addEventListener('auxclick', function(e) {
    // Handle middle-click (button 1) on icon links
    if (e.button === 1 && e.target.closest('a[phx-click]')) {
        const link = e.target.closest('a[phx-click]');
        
        // Prevent the phx-click event from firing
        e.stopImmediatePropagation();
        
        // Let browser handle middle-click (open in new tab)
        return true;
    }
});

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// Global function for panel toggle in Big mode (details and map)
window.togglePanel = function(header, panelType) {
    // Find the appropriate panel element
    let panelElement;
    if (panelType === 'details') {
        panelElement = document.querySelector('.photo-details-container.big-mode .photo_table');
    } else if (panelType === 'map') {
        panelElement = document.querySelector('.photo-map-container.big-mode .photo-map');
    }
    
    if (!panelElement) return;
    
    // Check if this panel is currently expanded
    const isCurrentlyExpanded = panelElement.classList.contains('expanded');
    
    if (isCurrentlyExpanded) {
        // Close this panel (clicking same button to close)
        panelElement.classList.remove('expanded');
        header.classList.remove('expanded');
    } else {
        // Close any other open panels first, then open this one
        closeAllPanels();
        
        panelElement.classList.add('expanded');
        header.classList.add('expanded');
        
        // If it's a map, trigger resize
        if (panelType === 'map') {
            setTimeout(() => {
                const mapInstance = window.mapInstances && window.mapInstances[panelElement.id];
                if (mapInstance) {
                    mapInstance.invalidateSize();
                }
            }, 100);
        }
    }
};

// Helper function to close all panels in Big mode
function closeAllPanels() {
    // Close details panel
    const detailsPanel = document.querySelector('.photo-details-container.big-mode .photo_table');
    const detailsHeader = document.querySelector('.details-header');
    if (detailsPanel) {
        detailsPanel.classList.remove('expanded');
    }
    if (detailsHeader) {
        detailsHeader.classList.remove('expanded');
    }
    
    // Close map panel
    const mapPanel = document.querySelector('.photo-map-container.big-mode .photo-map');
    const mapHeader = document.querySelector('.big-mode-controls .map-header');
    if (mapPanel) {
        mapPanel.classList.remove('expanded');
    }
    if (mapHeader) {
        mapHeader.classList.remove('expanded');
    }
}

// Click outside to close panels
document.addEventListener('click', function(event) {
    // Only handle this in big mode
    const bigModeControls = document.querySelector('.big-mode-controls');
    if (!bigModeControls) return;
    
    // Check if click is outside both control buttons and open panels
    const clickedButton = event.target.closest('.details-header, .map-header');
    const clickedPanel = event.target.closest('.photo-details-container.big-mode .photo_table.expanded, .photo-map-container.big-mode .photo-map.expanded');
    
    // If clicked outside buttons and panels, close all
    if (!clickedButton && !clickedPanel) {
        closeAllPanels();
    }
});

// Global function for details toggle (legacy - kept for compatibility)
window.toggleDetails = function(header) {
    togglePanel(header, 'details');
};

// Global function for map toggle (updated for normal mode)
window.toggleMap = function(header) {
    const mapContainer = header.parentElement;
    const mapElement = mapContainer.querySelector('.photo-map');
    const isBigMode = mapContainer.classList.contains('big-mode');
    
    if (isBigMode) {
        // Big mode: toggle between none/block using expanded class
        const isExpanded = mapElement.classList.contains('expanded');
        
        if (isExpanded) {
            mapElement.classList.remove('expanded');
            header.classList.remove('expanded');
        } else {
            mapElement.classList.add('expanded');
            header.classList.add('expanded');
        }
    } else {
        // Normal mode: toggle between none/block using collapsed class
        const isCollapsed = mapElement.classList.contains('collapsed');
        
        if (isCollapsed) {
            mapElement.classList.remove('collapsed');
            header.classList.remove('collapsed');
        } else {
            mapElement.classList.add('collapsed');
            header.classList.add('collapsed');
        }
    }
    
    // Trigger map resize if it becomes visible
    const isVisible = isBigMode ? 
        mapElement.classList.contains('expanded') : 
        !mapElement.classList.contains('collapsed');
        
    if (isVisible) {
        setTimeout(() => {
            const mapInstance = window.mapInstances && window.mapInstances[mapElement.id];
            if (mapInstance) {
                mapInstance.invalidateSize();
            }
        }, 100);
    }
};
