<%@ page contentType="text/html;charset=UTF-8" language="java" pageEncoding="UTF-8" %>
<%@ page import="java.io.*,java.util.Base64,java.time.*,java.time.format.DateTimeFormatter" %>
<%
    // --- Simple server-side handler: save Base64 image to filesystem ---
    String savedPath = null;
    String errorMsg = null;

    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String imageBase64 = request.getParameter("imageBase64");
        try {
            if (imageBase64 == null || imageBase64.trim().isEmpty()) {
                throw new IllegalArgumentException("No image data received.");
            }
            // Expect data URL like: data:image/jpeg;base64,<...>
            int commaIdx = imageBase64.indexOf(',');
            if (commaIdx < 0) throw new IllegalArgumentException("Invalid data URL.");
            String header = imageBase64.substring(0, commaIdx); // e.g., data:image/jpeg;base64
            String dataPart = imageBase64.substring(commaIdx + 1);

            String mime = "image/jpeg"; // default
            int semiIdx = header.indexOf(';');
            if (header.startsWith("data:") && semiIdx > 5) {
                mime = header.substring(5, semiIdx); // between "data:" and ";"
            }
            String ext = "jpg";
            if ("image/png".equalsIgnoreCase(mime)) ext = "png";

            byte[] bytes = Base64.getDecoder().decode(dataPart);

            // Save to temp dir: <tmp>/idphoto-uploads/idphoto-YYYYMMdd-HHmmss-SSS.ext
            File baseDir = new File(System.getProperty("java.io.tmpdir"), "idphoto-uploads");
            if (!baseDir.exists() && !baseDir.mkdirs()) {
                throw new IOException("Unable to create upload directory: " + baseDir.getAbsolutePath());
            }
            String ts = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss-SSS"));
            File out = new File(baseDir, "idphoto-" + ts + "." + ext);

            try (FileOutputStream fos = new FileOutputStream(out)) {
                fos.write(bytes);
                fos.flush();
            }
            savedPath = out.getAbsolutePath();
        } catch (Exception ex) {
            errorMsg = ex.getMessage();
        }
    }
%>
<!DOCTYPE html>
<html>
<head>
    <title>Cropper.js Demo (Single JSP)</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <!-- jQuery (for convenience in this demo) -->
    <script src="https://code.jquery.com/jquery-3.7.1.min.js"
            integrity="sha256-/JqT3SQfawRcv/BIHPThkBvs0OEvtFFmqPF/lYI/Cxo="
            crossorigin="anonymous"></script>

    <!-- Cropper.js (CDN for demo; switch to local files if preferred) -->
    <link  href="https://unpkg.com/cropperjs@1.6.2/dist/cropper.min.css" rel="stylesheet"/>
    <script src="https://unpkg.com/cropperjs@1.6.2/dist/cropper.min.js"></script>

    <style>
        body { font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif; margin: 24px; }
        .btn { padding: 8px 14px; border: 1px solid #ccc; background: #f7f7f7; cursor: pointer; border-radius: 4px; }
        .btn.primary { background: #1976d2; color: #fff; border-color: #1976d2; }
        .btn:disabled { opacity: .6; cursor: not-allowed; }
        .panel { display:none; margin-top:16px; border:1px solid #ddd; border-radius:6px; padding:16px; }
        .grid { display:grid; grid-template-columns: 280px 1fr; gap:16px; }
        .guide { border:1px solid #eee; padding:10px; }
        .guide img { max-width:100%; display:block; }
        .crop-area { min-height: 420px; border:1px dashed #bbb; display:flex; align-items:center; justify-content:center; background:#fafafa; }
        .crop-area img { max-width: 100%; }
        .preview { margin-top:8px; border:1px solid #eee; padding:8px; }
        .footer { display:flex; gap:8px; justify-content:flex-end; margin-top:12px; }
        .alert { margin-top: 16px; padding:10px; border-radius:4px; }
        .alert.ok { background:#e8f5e9; border:1px solid #c8e6c9; }
        .alert.err { background:#ffebee; border:1px solid #ffcdd2; }
        .muted { color:#666; font-size: 12px; }
    </style>
</head>
<body>

<h2>Upload & Crop Demo (Cropper.js)</h2>

<form id="saveForm" method="post" style="display:none;">
    <input type="hidden" name="imageBase64" id="imageBase64">
</form>

<button id="openBtn" class="btn primary">Open uploader</button>

<div id="panel" class="panel">
    <div class="grid">
        <div class="guide">
            <p><strong>Photo guidelines</strong></p>
            <ul>
                <li>Neutral expression, plain light background</li>
                <li>Face centered, head fully visible</li>
                <li>No hats or sunglasses</li>
            </ul>
            <!-- Use any local guideline image if you have one -->
            <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/7/74/UK_passport_sample_%28bilingual%29.svg/320px-UK_passport_sample_%28bilingual%29.svg.png"
                 alt="UK passport guideline (illustrative)">
            <div class="preview">
                <p><strong>Preview</strong> <span class="muted">(700×900 output)</span></p>
                <canvas id="previewCanvas" style="max-width:100%;"></canvas>
            </div>
        </div>

        <div>
            <div style="margin-bottom:8px;">
                <input type="file" id="fileInput" accept="image/*">
            </div>
            <div class="crop-area">
                <img id="cropperImage" alt="Selected" style="display:none;">
                <div id="placeholder">Choose a photo to start cropping…</div>
            </div>
            <div class="footer">
                <button id="saveBtn" class="btn primary" disabled>Save to filesystem</button>
                <button id="cancelBtn" class="btn">Cancel</button>
            </div>
        </div>
    </div>
</div>

<% if (savedPath != null) { %>
<div class="alert ok">
    <strong>Saved.</strong> File written to: <code><%= savedPath %></code>
</div>
<% } else if (errorMsg != null) { %>
<div class="alert err">
    <strong>Error:</strong> <%= errorMsg %>
</div>
<% } %>

<script>
    (function($){
        var cropper = null;
        var $panel = $('#panel');
        var $openBtn = $('#openBtn');
        var $cancelBtn = $('#cancelBtn');
        var $saveBtn = $('#saveBtn');
        var $file = $('#fileInput');
        var $img = $('#cropperImage');
        var $placeholder = $('#placeholder');
        var $preview = document.getElementById('previewCanvas');

        function openPanel() {
            $panel.slideDown(150);
        }
        function closePanel() {
            $panel.slideUp(150);
            teardown();
        }
        function teardown() {
            if (cropper) {
                try { cropper.destroy(); } catch(e){}
                cropper = null;
            }
            $img.hide().attr('src','');
            $placeholder.show();
            $file.val('');
            $saveBtn.prop('disabled', true).text('Save to filesystem');
            var ctx = $preview.getContext('2d');
            if (ctx) ctx.clearRect(0,0,$preview.width,$preview.height);
        }

        function initCropper() {
            if (cropper) { try { cropper.destroy(); } catch(e){} }
            cropper = new Cropper($img[0], {
                aspectRatio: 35/45,     // UK ID style ratio
                viewMode: 1,
                autoCropArea: 1,
                movable: true,
                zoomable: true,
                background: false,
                ready: function(){ $saveBtn.prop('disabled', false); updatePreview(); },
                crop: function(){ updatePreview(); }
            });
        }

        function updatePreview() {
            if (!cropper) return;
            var canvas = cropper.getCroppedCanvas({ width: 700, height: 900 });
            if (!canvas) return;
            $preview.width = canvas.width;
            $preview.height = canvas.height;
            var ctx = $preview.getContext('2d');
            ctx.drawImage(canvas, 0, 0);
        }

        function objectUrl(file) {
            return (window.URL || window.webkitURL).createObjectURL(file);
        }

        $openBtn.on('click', function(e){ e.preventDefault(); openPanel(); });

        $cancelBtn.on('click', function(e){ e.preventDefault(); closePanel(); });

        $file.on('change', function(){
            var f = this.files && this.files[0];
            if (!f) return;
            if (!/^image\/(jpeg|jpg|png)$/i.test(f.type)) {
                alert('Please choose a JPEG or PNG image.');
                this.value = '';
                return;
            }
            $placeholder.hide();
            $img.show().attr('src', objectUrl(f)).one('load', function(){ initCropper(); });
        });

        $('#saveBtn').on('click', function(e){
            e.preventDefault();
            if (!cropper) return;
            var canvas = cropper.getCroppedCanvas({ width: 700, height: 900 });
            if (!canvas) { alert('Could not crop.'); return; }

            // Send as Base64 data URL via hidden form to this same JSP
            var dataUrl = canvas.toDataURL('image/jpeg', 0.92); // or 'image/png'
            $('#imageBase64').val(dataUrl);

            $saveBtn.prop('disabled', true).text('Saving…');
            $('#saveForm')[0].submit();
        });
    })(jQuery);
</script>

</body>
</html>