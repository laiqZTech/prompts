<%@ page contentType="text/html;charset=UTF-8" language="java" pageEncoding="UTF-8" %>
<%@ page import="java.io.*,java.util.Base64,java.time.*,java.time.format.DateTimeFormatter" %>
<%
    String savedPath = null, errorMsg = null;
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        try {
            String dataUrl = request.getParameter("imageBase64");
            if (dataUrl == null || dataUrl.isEmpty()) throw new IllegalArgumentException("No image data.");
            int comma = dataUrl.indexOf(',');
            if (comma < 0) throw new IllegalArgumentException("Invalid data URL.");
            String header = dataUrl.substring(0, comma);          // data:image/jpeg;base64
            String base64 = dataUrl.substring(comma + 1);
            String mime = "image/jpeg";
            int semi = header.indexOf(';');
            if (header.startsWith("data:") && semi > 5) mime = header.substring(5, semi);
            String ext = "jpg"; if ("image/png".equalsIgnoreCase(mime)) ext = "png";

            byte[] bytes = Base64.getDecoder().decode(base64);

            File dir = new File(System.getProperty("java.io.tmpdir"), "idphoto-uploads");
            if (!dir.exists() && !dir.mkdirs()) throw new IOException("Cannot create " + dir.getAbsolutePath());
            String ts = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss-SSS"));
            File out = new File(dir, "idphoto-" + ts + "." + ext);
            try (FileOutputStream fos = new FileOutputStream(out)) { fos.write(bytes); }
            savedPath = out.getAbsolutePath();
        } catch (Exception e) {
            errorMsg = e.getMessage();
        }
    }
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Upload & Crop Photo</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <!-- jQuery + Cropper.js from CDN for quick test -->
    <script src="https://code.jquery.com/jquery-3.7.1.min.js"
            integrity="sha256-/JqT3SQfawRcv/BIHPThkBvs0OEvtFFmqPF/lYI/Cxo=" crossorigin="anonymous"></script>
    <link rel="stylesheet" href="https://unpkg.com/cropperjs@1.6.2/dist/cropper.min.css">
    <script src="https://unpkg.com/cropperjs@1.6.2/dist/cropper.min.js"></script>
    <style>
        body { font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif; margin: 16px; }
        .row { display: grid; grid-template-columns: 320px 1fr; gap: 16px; }
        .box { border:1px solid #ddd; border-radius:6px; padding:12px; }
        .crop { min-height:420px; display:flex; align-items:center; justify-content:center;
            background:#fafafa; border:1px dashed #bbb; }
        .crop img { max-width:100%; }
        .btn { padding:8px 14px; border:1px solid #ccc; background:#f7f7f7; border-radius:4px; cursor:pointer; }
        .btn.primary { background:#1976d2; color:#fff; border-color:#1976d2; }
        .btn:disabled { opacity:.6; cursor:not-allowed; }
        .actions { margin-top:12px; display:flex; gap:8px; }
        .ok { color:#256029; margin-top:10px; }
        .err { color:#b00020; margin-top:10px; }
    </style>
</head>
<body>
<h3>Upload & Crop Photo</h3>

<form id="saveForm" method="post" style="display:none;">
    <input type="hidden" name="imageBase64" id="imageBase64">
</form>

<div class="row">
    <div class="box">
        <p><strong>Preview</strong> (700×900)</p>
        <canvas id="preview" style="max-width:100%;"></canvas>
        <div class="actions">
            <button id="saveBtn" class="btn primary" disabled>Save</button>
            <button id="closeBtn" class="btn" type="button" onclick="window.close()">Close</button>
        </div>
        <% if (savedPath != null) { %>
        <div class="ok">Saved to: <code><%= savedPath %></code></div>
        <% } else if (errorMsg != null) { %>
        <div class="err">Error: <%= errorMsg %></div>
        <% } %>
    </div>

    <div class="box">
        <input type="file" id="file" accept="image/*">
        <div class="crop" style="margin-top:8px;">
            <img id="img" alt="Selected" style="display:none;">
            <div id="ph">Choose a photo…</div>
        </div>
    </div>
</div>

<script>
    (function($){
        var cropper = null, $img = $('#img'), $ph = $('#ph'), $file = $('#file'),
            $save = $('#saveBtn'), preview = document.getElementById('preview');

        function initCropper(){
            if (cropper) { try { cropper.destroy(); } catch(e){} }
            cropper = new Cropper($img[0], {
                aspectRatio: 35/45, viewMode: 1, autoCropArea: 1,
                movable: true, zoomable: true, background: false,
                ready: function(){ $save.prop('disabled', false); drawPreview(); },
                crop: drawPreview
            });
        }
        function drawPreview(){
            if (!cropper) return;
            var c = cropper.getCroppedCanvas({ width: 700, height: 900 });
            if (!c) return;
            preview.width = c.width; preview.height = c.height;
            preview.getContext('2d').drawImage(c,0,0);
        }
        function urlOf(f){ return (window.URL||window.webkitURL).createObjectURL(f); }

        $file.on('change', function(){
            var f = this.files && this.files[0];
            if (!f) return;
            if (!/^image\/(jpeg|jpg|png)$/i.test(f.type)) { alert('Pick a JPEG or PNG'); this.value=''; return; }
            $ph.hide(); $img.show().attr('src', urlOf(f)).one('load', initCropper);
        });

        $save.on('click', function(e){
            e.preventDefault(); if (!cropper) return;
            var c = cropper.getCroppedCanvas({ width: 700, height: 900 });
            if (!c) { alert('Could not crop'); return; }
            var dataUrl = c.toDataURL('image/jpeg', 0.92);
            document.getElementById('imageBase64').value = dataUrl;
            $save.prop('disabled', true).text('Saving…');
            document.getElementById('saveForm').submit();
        });
    })(jQuery);
</script>
</body>
</html>

<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<a href="<c:url value='/cropper-popup.jsp'/>"
   onclick="window.open(this.href,'cropper',
     'width=980,height=720,menubar=0,toolbar=0,location=0,status=0,scrollbars=1,resizable=1'); return false;">
    Upload & Crop Photo
</a>