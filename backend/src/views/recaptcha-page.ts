/**
 * The page that hosts the real Google reCAPTCHA v2 checkbox.
 *
 * It is served by the API so the widget's browser origin is a normal HTTP
 * origin rather than a file:// page. The token comes back through:
 *   - `RecaptchaBridge.postMessage(token)` inside the Android WebView,
 *   - `window.parent.postMessage(...)` inside an iframe on web,
 *   - `window.opener.postMessage(...)` when opened as a popup.
 */
export function recaptchaPage(siteKey: string, popup: boolean): string {
  const key = JSON.stringify(siteKey);
  const isPopup = JSON.stringify(popup);

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
  <title>Tahanan · Google reCAPTCHA</title>
  <style>
    :root { color-scheme: light; }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      display: grid;
      place-items: center;
      padding: 22px;
      background: linear-gradient(180deg, #f3fbf6 0%, #e8f7ef 100%);
      color: #0b1f14;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
    }
    main {
      width: 100%;
      max-width: 360px;
      padding: 22px;
      background: #ffffff;
      border: 1px solid #d8eee2;
      border-radius: 20px;
      box-shadow: 0 18px 40px rgba(12, 43, 27, 0.12);
      text-align: center;
    }
    .mark {
      width: 46px;
      height: 46px;
      display: grid;
      place-items: center;
      margin: 0 auto 10px;
      border-radius: 14px;
      background: #0f7a44;
      color: #ffffff;
      font-size: 22px;
      font-weight: 800;
    }
    h1 { margin: 0 0 6px; font-size: 17px; letter-spacing: -0.3px; }
    p { margin: 0 0 14px; color: #5b6b62; font-size: 12.5px; line-height: 1.45; }
    #captcha { display: flex; justify-content: center; min-height: 78px; }
    #status { min-height: 18px; margin: 12px 0 0; font-size: 12px; font-weight: 600; color: #0f7a44; }
    #status.error { color: #b3261e; }
    button {
      margin-top: 12px;
      padding: 9px 16px;
      border: 1px solid #cfe6d9;
      border-radius: 999px;
      background: #f3fbf6;
      color: #0f7a44;
      font: inherit;
      font-size: 12.5px;
      font-weight: 700;
      cursor: pointer;
    }
    .config {
      padding: 14px;
      border-radius: 12px;
      background: #fff7e6;
      color: #7a4b00;
      font-size: 12px;
      line-height: 1.5;
      text-align: left;
    }
    .config code {
      display: block;
      margin-top: 6px;
      font-size: 11px;
      overflow-wrap: anywhere;
    }
  </style>
</head>
<body>
  <main>
    <div class="mark">T</div>
    <h1>Verify you're human</h1>
    <p>Complete the Google reCAPTCHA to continue to Tahanan.</p>
    <div id="captcha"></div>
    <div id="fallback" hidden class="config">
      Google reCAPTCHA is not configured on this server yet. Add
      <code>RECAPTCHA_SITE_KEY</code> and <code>RECAPTCHA_SECRET_KEY</code>
      to the backend .env, then restart.
    </div>
    <p id="status"></p>
    <button id="reset" type="button">Reset verification</button>
  </main>
  <script>
    (function () {
      var siteKey = ${key};
      var isPopup = ${isPopup};
      var status = document.getElementById('status');
      var fallback = document.getElementById('fallback');
      var resetButton = document.getElementById('reset');
      var widgetId = null;

      function setStatus(text, isError) {
        status.textContent = text || '';
        status.className = isError ? 'error' : '';
      }

      function deliver(token) {
        if (!token) return;
        setStatus('Verified. You can return to Tahanan.');

        try {
          if (window.RecaptchaBridge && window.RecaptchaBridge.postMessage) {
            window.RecaptchaBridge.postMessage(token);
          }
        } catch (error) {}

        try {
          if (window.parent && window.parent !== window) {
            window.parent.postMessage(token, '*');
          }
        } catch (error) {}

        try {
          if (isPopup && window.opener) {
            window.opener.postMessage(token, '*');
            window.setTimeout(function () { window.close(); }, 450);
          }
        } catch (error) {}
      }

      window.tahananRecaptchaLoaded = function () {
        if (!window.grecaptcha || !siteKey) return;
        try {
          widgetId = window.grecaptcha.render('captcha', {
            sitekey: siteKey,
            callback: deliver,
            'expired-callback': function () {
              setStatus('The verification expired. Please tick the box again.', true);
              deliver('');
            },
            'error-callback': function () {
              setStatus('Google could not load the widget. Check the site key and domain.', true);
            }
          });
        } catch (error) {
          setStatus('Google could not render the widget: ' + (error && error.message ? error.message : 'unknown error'), true);
        }
      };

      resetButton.addEventListener('click', function () {
        setStatus('');
        if (window.grecaptcha && widgetId !== null) {
          window.grecaptcha.reset(widgetId);
        }
      });

      if (!siteKey) {
        fallback.hidden = false;
        document.getElementById('captcha').hidden = true;
        resetButton.hidden = true;
        setStatus('reCAPTCHA is not configured.', true);
        return;
      }

      var script = document.createElement('script');
      script.src = 'https://www.google.com/recaptcha/api.js?onload=tahananRecaptchaLoaded&render=explicit';
      script.async = true;
      script.defer = true;
      script.onerror = function () {
        setStatus('Could not reach Google reCAPTCHA. Check the connection.', true);
      };
      document.head.appendChild(script);
    })();
  </script>
</body>
</html>`;
}
