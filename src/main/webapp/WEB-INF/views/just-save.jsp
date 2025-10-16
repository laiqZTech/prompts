<%@ page contentType="application/json;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.io.*,java.util.Base64,java.time.*,java.time.format.DateTimeFormatter" %>
<%
  String imageBase64 = request.getParameter("imageBase64");
  try {
    if (imageBase64 == null || imageBase64.trim().isEmpty()) {
      throw new IllegalArgumentException("No image data.");
    }
    int comma = imageBase64.indexOf(',');
    if (comma < 0) throw new IllegalArgumentException("Invalid data URL.");
    String header = imageBase64.substring(0, comma);  // e.g. data:image/jpeg;base64
    String data   = imageBase64.substring(comma + 1);

    String mime = "image/jpeg";
    int semi = header.indexOf(';');
    if (header.startsWith("data:") && semi > 5) mime = header.substring(5, semi);
    String ext = "jpg";
    if ("image/png".equalsIgnoreCase(mime)) ext = "png";

    byte[] bytes = Base64.getDecoder().decode(data);

    File dir = new File(System.getProperty("java.io.tmpdir"), "idphoto-uploads");
    if (!dir.exists() && !dir.mkdirs()) throw new IOException("Cannot create " + dir.getAbsolutePath());
    String ts = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss-SSS"));
    File out = new File(dir, "idphoto-" + ts + "." + ext);
    try (FileOutputStream fos = new FileOutputStream(out)) { fos.write(bytes); }

    out.clearBuffer();
    out.print("{\"status\":\"ok\",\"path\":\"" + out.getAbsolutePath().replace("\\","\\\\") + "\"}");
  } catch (Exception ex) {
    out.clearBuffer();
    String msg = ex.getMessage() == null ? "Error" : ex.getMessage().replace("\"","\\\"");
    out.print("{\"status\":\"error\",\"error\":\"" + msg + "\"}");
  }
%>