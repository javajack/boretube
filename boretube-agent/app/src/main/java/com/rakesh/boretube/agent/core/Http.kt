package com.rakesh.boretube.agent.core

import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.net.URLDecoder
import java.security.MessageDigest

class HttpParseException(val status: Int, message: String) : IOException(message)

data class HttpRequest(
    val method: String,
    val path: String,
    val query: Map<String, String>,
    /** Lower-cased header names. */
    val headers: Map<String, String>,
    val body: String,
) {
    fun header(name: String): String? = headers[name.lowercase()]

    companion object {
        const val MAX_HEADER_BYTES = 16 * 1024
        const val MAX_BODY_BYTES = 256 * 1024

        /** Parses one HTTP/1.1 request. Returns null on a clean EOF before any byte. */
        fun parse(input: InputStream): HttpRequest? {
            val head = readHead(input) ?: return null
            val lines = head.split("\r\n")
            val requestLine = lines.first().split(' ')
            if (requestLine.size != 3 || !requestLine[2].startsWith("HTTP/1.")) {
                throw HttpParseException(400, "bad request line")
            }
            val method = requestLine[0].uppercase()
            val target = requestLine[1]
            val headers = linkedMapOf<String, String>()
            for (l in lines.drop(1)) {
                if (l.isEmpty()) continue
                val i = l.indexOf(':')
                if (i <= 0) throw HttpParseException(400, "bad header")
                headers[l.substring(0, i).trim().lowercase()] = l.substring(i + 1).trim()
            }
            if (headers["transfer-encoding"] != null) throw HttpParseException(411, "chunked bodies not supported")
            val len = headers["content-length"]?.let {
                it.toIntOrNull() ?: throw HttpParseException(400, "bad content-length")
            } ?: 0
            if (len < 0) throw HttpParseException(400, "bad content-length")
            if (len > MAX_BODY_BYTES) throw HttpParseException(413, "body too large")
            val body = ByteArray(len)
            var off = 0
            while (off < len) {
                val n = input.read(body, off, len - off)
                if (n < 0) throw HttpParseException(400, "truncated body")
                off += n
            }
            val q = target.indexOf('?')
            val path = if (q < 0) target else target.substring(0, q)
            val query = if (q < 0) emptyMap() else parseQuery(target.substring(q + 1))
            return HttpRequest(method, path, query, headers, String(body, Charsets.UTF_8))
        }

        private fun readHead(input: InputStream): String? {
            val buf = ByteArrayOutputStream()
            var state = 0 // matched bytes of \r\n\r\n
            while (true) {
                val b = input.read()
                if (b < 0) {
                    if (buf.size() == 0) return null
                    throw HttpParseException(400, "truncated head")
                }
                buf.write(b)
                if (buf.size() > MAX_HEADER_BYTES) throw HttpParseException(431, "headers too large")
                state = when {
                    state == 0 && b == '\r'.code -> 1
                    state == 1 && b == '\n'.code -> 2
                    state == 2 && b == '\r'.code -> 3
                    state == 3 && b == '\n'.code -> 4
                    b == '\r'.code -> 1
                    else -> 0
                }
                if (state == 4) {
                    val s = buf.toString(Charsets.ISO_8859_1.name())
                    return s.substring(0, s.length - 4)
                }
            }
        }

        fun parseQuery(q: String): Map<String, String> = q.split('&').filter { it.isNotEmpty() }.associate {
            val i = it.indexOf('=')
            val k = if (i < 0) it else it.substring(0, i)
            val v = if (i < 0) "" else it.substring(i + 1)
            URLDecoder.decode(k, "UTF-8") to URLDecoder.decode(v, "UTF-8")
        }
    }
}

data class HttpResponse(val status: Int, val body: String, val contentType: String = "application/json; charset=utf-8") {
    fun write(out: OutputStream) {
        val bytes = body.toByteArray(Charsets.UTF_8)
        val head = buildString {
            append("HTTP/1.1 ").append(status).append(' ').append(reason(status)).append("\r\n")
            append("Content-Type: ").append(contentType).append("\r\n")
            append("Content-Length: ").append(bytes.size).append("\r\n")
            append("Cache-Control: no-store\r\n")
            if (status == 401) append("WWW-Authenticate: Bearer\r\n")
            append("Connection: close\r\n\r\n")
        }
        out.write(head.toByteArray(Charsets.ISO_8859_1))
        out.write(bytes)
        out.flush()
    }

    companion object {
        fun reason(s: Int) = when (s) {
            200 -> "OK"; 400 -> "Bad Request"; 401 -> "Unauthorized"; 404 -> "Not Found"
            405 -> "Method Not Allowed"; 409 -> "Conflict"; 411 -> "Length Required"
            413 -> "Payload Too Large"; 431 -> "Request Header Fields Too Large"
            500 -> "Internal Server Error"; 503 -> "Service Unavailable"; else -> "Status"
        }
    }
}

object Auth {
    /** Constant-time bearer check. */
    fun authorized(header: String?, token: String): Boolean {
        if (header == null || token.isEmpty()) return false
        val prefix = "Bearer "
        if (!header.startsWith(prefix)) return false
        val given = header.substring(prefix.length).trim().toByteArray()
        return MessageDigest.isEqual(given, token.toByteArray())
    }
}

/** Clock-skew check from the phone's `X-Phone-Time` hint (epoch ms or ISO). */
object ClockSkew {
    const val WARN_MS = 2 * 60_000L

    fun parsePhoneTime(v: String?): Long? {
        if (v.isNullOrBlank()) return null
        v.trim().toLongOrNull()?.let { return it }
        return Rules.parseIsoInstant(v.trim(), java.time.ZoneOffset.UTC)?.toEpochMilli()
    }

    /** Agent time minus phone time. */
    fun skewMs(agentNow: Long, phoneTime: Long): Long = agentNow - phoneTime

    fun warn(skewMs: Long?): Boolean = skewMs != null && kotlin.math.abs(skewMs) > WARN_MS
}
