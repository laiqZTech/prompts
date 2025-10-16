<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<!-- Requires jQuery already on the page -->

<!-- Cropper assets (CDN for quick test; move to local if you prefer) -->
<link rel="stylesheet" href="https://unpkg.com/cropperjs@1.6.2/dist/cropper.min.css">
<script src="https://unpkg.com/cropperjs@1.6.2/dist/cropper.min.js"></script>

<style>
    .idp-wrap { margin: 12px 0; }
    .idp-btn { padding: 6px 12px; border: 1px solid #ccc; background:#f7f7f7; border-radius:4px; cursor:pointer; }
    .idp-panel { display:none; margin-top:12px; border:1px solid #ddd; border-radius:6px; padding:12px; }
    .idp-grid { display:grid; grid-template-columns: 260px 1fr; gap:12px; }
    .idp-guide { border:1px solid #eee; padding:8px; }
    .idp-guide img { max-width:100%; display:block; }
    .idp-crop { min-height:380px; border:1px dashed #bbb; display:flex; align-items:center; justify-content:center; background:#fafafa; }
    .idp-crop img { max-width:100%; }
    .idp-footer { display:flex; gap:8px; justify-content:flex-end; margin-top:10px; }
    .idp-alert { margin-top:10px; font-size:13px; }
    .idp-ok { color:#256029; }
    .idp-err { color:#b00020; }
</style>

<div class="idp-wrap" id="idp">
    <button type="button" class="idp-btn" id="idp-open">Upload ID Photo</button>

    <div class="idp-panel" id="idp-panel">
        <div class="idp-grid">
            <div class="idp-guide">
                <p><strong>Guidelines</strong></p>
                <ul>
                    <li>Neutral expression, plain light background</li>
                    <li>Face centered, head fully visible</li>
                    <li>No hats or sunglasses</li>
                </ul>
                <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/7/74/UK_passport_sample_%28bilingual%29.svg/240px-UK_passport_sample_%28bilingual%29.svg.png"
                     alt="UK passport example">
                <div style="margin-top:8px;">
                    <p><strong>Preview (700×900)</strong></p>
                    <canvas id="idp-preview" style="max-width:100%;"></canvas>
                </div>
            </div>

            <div>
                <div style="margin-bottom:8px;">
                    <input type="file" id="idp-file" accept="image/*">
                </div>
                <div class="idp-crop">
                    <img id="idp-img" alt="Selected" style="display:none;">
                    <div id="idp-ph">Choose a photo to start cropping…</div>
                </div>
                <div class="idp-footer">
                    <button type="button" class="idp-btn" id="idp-save" disabled>Save to filesystem</button>
                    <button type="button" class="idp-btn" id="idp-cancel">Cancel</button>
                </div>
            </div>
        </div>

        <div class="idp-alert" id="idp-msg"></div>
    </div>
</div>

<script>
    (function($){
        var cropper = null;
        var $panel = $('#idp-panel');
        var $open  = $('#idp-open');
        var $cancel= $('#idp-cancel');
        var $save  = $('#idp-save');
        var $file  = $('#idp-file');
        var $img   = $('#idp-img');
        var $ph    = $('#idp-ph');
        var $msg   = $('#idp-msg');
        var preview = document.getElementById('idp-preview');

        function openPanel(){ $panel.slideDown(120); }
        function closePanel(){ $panel.slideUp(120); reset(); }

        function reset(){
            if (cropper) { try { cropper.destroy(); } catch(e){} cropper = null; }
            $img.hide().attr('src','');
            $ph.show();
            $file.val('');
            $save.prop('disabled', true).text('Save to filesystem');
            $msg.removeClass('idp-ok idp-err').text('');
            var ctx = preview.getContext('2d'); ctx && ctx.clearRect(0,0,preview.width,preview.height);
        }

        function initCropper(){
            if (cropper) { try { cropper.destroy(); } catch(e){} }
            cropper = new Cropper($img[0], {
                aspectRatio: 35/45,
                viewMode: 1,
                autoCropArea: 1,
                movable: true,
                zoomable: true,
                background: false,
                ready: function(){ $save.prop('disabled', false); updatePreview(); },
                crop: function(){ updatePreview(); }
            });
        }

        function updatePreview(){
            if (!cropper) return;
            var canvas = cropper.getCroppedCanvas({ width: 700, height: 900 });
            if (!canvas) return;
            preview.width = canvas.width; preview.height = canvas.height;
            preview.getContext('2d').drawImage(canvas,0,0);
        }

        function objUrl(f){ return (window.URL||window.webkitURL).createObjectURL(f); }

        $open.on('click', function(e){ e.preventDefault(); openPanel(); });
        $cancel.on('click', function(e){ e.preventDefault(); closePanel(); });

        $file.on('change', function(){
            var f = this.files && this.files[0];
            if (!f) return;
            if (!/^image\/(jpeg|jpg|png)$/i.test(f.type)) {
                $msg.addClass('idp-err').text('Please choose a JPEG or PNG image.');
                this.value=''; return;
            }
            $ph.hide();
            $img.show().attr('src', objUrl(f)).one('load', initCropper);
        });

        $('#idp-save').on('click', function(e){
            e.preventDefault();
            if (!cropper) return;
            var canvas = cropper.getCroppedCanvas({ width: 700, height: 900 });
            if (!canvas) { $msg.addClass('idp-err').text('Could not crop.'); return; }

            var dataUrl = canvas.toDataURL('image/jpeg', 0.92);

            $save.prop('disabled', true).text('Saving…');
            $.ajax({
                url: '<c:url value="/identityPhoto-save.jsp"/>' , // saver JSP below
                method: 'POST',
                data: { imageBase64: dataUrl },
                success: function(res){
                    // res is JSON; show path
                    try {
                        var o = (typeof res === 'string') ? JSON.parse(res) : res;
                        if (o.status === 'ok') {
                            $msg.removeClass('idp-err').addClass('idp-ok').text('Saved: ' + o.path);
                            // closePanel(); // uncomment if you want to auto-close
                        } else {
                            $msg.removeClass('idp-ok').addClass('idp-err').text(o.error || 'Save failed.');
                        }
                    } catch(ex){
                        $msg.removeClass('idp-ok').addClass('idp-err').text('Unexpected response.');
                    }
                },
                error: function(xhr){
                    $msg.removeClass('idp-ok').addClass('idp-err').text('Save failed: ' + (xhr.responseText || xhr.statusText));
                },
                complete: function(){ $save.prop('disabled', false).text('Save to filesystem'); }
            });
        });

    })(jQuery);
</script>