import Foundation

/// JavaScript injected at document start. WKWebView implements neither the
/// Web Notifications API nor the Badging API, so both are shimmed and
/// bridged to the native side through script message handlers.
enum BridgeScripts {
    static let notifyHandler = "rivletNotify"
    static let permissionHandler = "rivletNotifyPermission"
    static let badgeHandler = "rivletBadge"

    static func notifications(initialPermission: String) -> String {
        """
        (function () {
          if (window.__rivletNotificationsInstalled) { return; }
          window.__rivletNotificationsInstalled = true;
          var permission = \(UserScriptWrapper.jsString(initialPermission));
          var registry = new Map();
          var nextId = 1;
          function post(msg) {
            try { window.webkit.messageHandlers.\(notifyHandler).postMessage(msg); } catch (e) {}
          }
          function RivletNotification(title, options) {
            options = options || {};
            var self = this;
            this.title = String(title);
            this.body = options.body ? String(options.body) : "";
            this.tag = options.tag ? String(options.tag) : "";
            this.icon = options.icon ? String(options.icon) : "";
            this.data = options.data;
            this.silent = !!options.silent;
            this.onclick = null; this.onclose = null; this.onshow = null; this.onerror = null;
            this._id = String(nextId++);
            this._listeners = {};
            registry.set(this._id, this);
            post({ type: "show", id: this._id, title: this.title, body: this.body, tag: this.tag, silent: this.silent });
            setTimeout(function () { self._fire("show"); }, 0);
          }
          RivletNotification.prototype.addEventListener = function (name, fn) {
            (this._listeners[name] = this._listeners[name] || []).push(fn);
          };
          RivletNotification.prototype.removeEventListener = function (name, fn) {
            var l = this._listeners[name]; if (!l) { return; }
            var i = l.indexOf(fn); if (i >= 0) { l.splice(i, 1); }
          };
          RivletNotification.prototype.dispatchEvent = function (ev) { this._fire(ev.type, ev); return true; };
          RivletNotification.prototype._fire = function (name, ev) {
            ev = ev || new Event(name);
            try { Object.defineProperty(ev, "target", { value: this }); } catch (e) {}
            var h = this["on" + name];
            if (typeof h === "function") { try { h.call(this, ev); } catch (e) { console.error(e); } }
            (this._listeners[name] || []).slice().forEach(function (fn) { try { fn.call(this, ev); } catch (e) { console.error(e); } }, this);
          };
          RivletNotification.prototype.close = function () {
            post({ type: "close", id: this._id });
            registry.delete(this._id);
            this._fire("close");
          };
          Object.defineProperty(RivletNotification, "permission", { get: function () { return permission; } });
          Object.defineProperty(RivletNotification, "maxActions", { get: function () { return 0; } });
          RivletNotification.requestPermission = function (callback) {
            var p;
            try {
              p = window.webkit.messageHandlers.\(permissionHandler).postMessage({}).then(function (r) {
                permission = String(r); return permission;
              });
            } catch (e) { p = Promise.resolve(permission); }
            if (typeof callback === "function") { p.then(callback); }
            return p;
          };
          window.__rivletNotificationClicked = function (id) {
            var n = registry.get(String(id));
            if (n) { n._fire("click"); }
          };
          window.__rivletNotificationClosed = function (id) {
            var n = registry.get(String(id));
            if (n) { registry.delete(String(id)); n._fire("close"); }
          };
          window.__rivletSetNotificationPermission = function (p) { permission = String(p); };
          try {
            Object.defineProperty(window, "Notification", { value: RivletNotification, configurable: true, writable: true });
          } catch (e) { window.Notification = RivletNotification; }
        })();
        """
    }

    static let badging = """
    (function () {
      if (!navigator || navigator.__rivletBadgeInstalled) { return; }
      navigator.__rivletBadgeInstalled = true;
      function send(count) {
        try { window.webkit.messageHandlers.\(badgeHandler).postMessage({ count: count }); } catch (e) {}
        return Promise.resolve();
      }
      navigator.setAppBadge = function (n) { return send(n === undefined ? -1 : Number(n)); };
      navigator.clearAppBadge = function () { return send(0); };
    })();
    """
}
