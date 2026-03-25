/**
 * Parse a curl command string into request components.
 * Optimized for Chrome/Firefox/Safari DevTools "Copy as cURL" output.
 *
 * Handles:
 *   -X/--request, -H/--header, -d/--data/--data-raw/--data-binary/--data-urlencode,
 *   -b/--cookie, -u/--user, -A/--user-agent, -e/--referer, --url,
 *   $'...' ANSI-C quoting (Chrome on Linux), combined short flags (-sS),
 *   line continuations, ^ continuation (Windows cmd)
 */
export function parseCurl(input) {
  // Normalize line continuations (unix \ and windows ^) and collapse whitespace
  const normalized = input
    .replace(/\\\s*\n/g, ' ')
    .replace(/\^\s*\n/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  const tokens = tokenize(normalized);
  if (!tokens.length || tokens[0].toLowerCase() !== 'curl') return null;

  let method = null;
  let url = '';
  let headers = [];
  let body = '';
  let bodyType = 'none';

  // Flags that take no argument — just skip them
  const noArgFlags = new Set([
    '--compressed', '-s', '--silent', '-S', '--show-error',
    '-k', '--insecure', '-v', '--verbose', '-L', '--location',
    '-i', '--include', '-N', '--no-buffer', '--raw', '--tr-encoding',
    '--globoff', '-G', '--get', '--http1.1', '--http2', '--http3',
    '-4', '--ipv4', '-6', '--ipv6', '-#', '--progress-bar',
    '-f', '--fail', '--fail-early', '--fail-with-body',
    '-n', '--netrc', '--netrc-optional',
    '--no-keepalive', '--no-sessionid', '--path-as-is',
    '--tcp-nodelay', '--tcp-fastopen',
  ]);

  // Flags that take one argument — skip both flag and value
  const skipWithArgFlags = new Set([
    '-o', '--output', '--connect-timeout',
    '-m', '--max-time', '--retry', '--retry-delay', '--retry-max-time',
    '-w', '--write-out', '-c', '--cookie-jar',
    '--ciphers', '--cert', '--cert-type', '--key', '--key-type',
    '--cacert', '--capath', '--pinnedpubkey',
    '--proxy', '-x', '--proxy-user', '-U',
    '--resolve', '--interface', '--local-port',
    '--max-redirs', '--limit-rate', '--speed-limit', '--speed-time',
    '--dns-servers', '--doh-url',
    '-D', '--dump-header', '--trace', '--trace-ascii',
    '--unix-socket', '--abstract-unix-socket',
    '--happy-eyeballs-timeout-ms',
    '-Y', '--speed-limit', '-y', '--speed-time',
    '-t', '--telnet-option', '-T', '--upload-file',
  ]);

  let i = 1;
  while (i < tokens.length) {
    const tok = tokens[i];

    if (tok === '-X' || tok === '--request') {
      method = (tokens[++i] || 'GET').toUpperCase();
    } else if (tok === '-H' || tok === '--header') {
      const val = tokens[++i] || '';
      const colonIdx = val.indexOf(':');
      if (colonIdx > 0) {
        headers.push({
          key: val.substring(0, colonIdx).trim(),
          value: val.substring(colonIdx + 1).trim(),
        });
      }
    } else if (tok === '-d' || tok === '--data' || tok === '--data-raw' || tok === '--data-binary') {
      body = tokens[++i] || '';
    } else if (tok === '--data-urlencode') {
      // Append as URL-encoded form data
      const val = tokens[++i] || '';
      body = body ? body + '&' + encodeURIComponent(val) : encodeURIComponent(val);
    } else if (tok === '-b' || tok === '--cookie') {
      const val = tokens[++i] || '';
      headers.push({ key: 'Cookie', value: val });
    } else if (tok === '-u' || tok === '--user') {
      const cred = tokens[++i] || '';
      headers.push({
        key: 'Authorization',
        value: 'Basic ' + btoa(cred),
      });
    } else if (tok === '-A' || tok === '--user-agent') {
      const val = tokens[++i] || '';
      headers.push({ key: 'User-Agent', value: val });
    } else if (tok === '-e' || tok === '--referer') {
      const val = tokens[++i] || '';
      headers.push({ key: 'Referer', value: val });
    } else if (tok === '--url') {
      url = tokens[++i] || '';
    } else if (noArgFlags.has(tok)) {
      // skip
    } else if (skipWithArgFlags.has(tok)) {
      i++; // skip the argument too
    } else if (tok.startsWith('-') && !tok.startsWith('--') && tok.length > 2) {
      // Combined short flags like -sSL — expand and re-process
      // Last flag might take an argument if it's a known arg-taking flag
      const flags = tok.slice(1).split('');
      let allNoArg = true;
      for (let f = 0; f < flags.length; f++) {
        const short = '-' + flags[f];
        if (f === flags.length - 1) {
          // Last flag in a combined group might take an argument
          if (short === '-d' || short === '-H' || short === '-b' ||
              short === '-u' || short === '-A' || short === '-e' ||
              short === '-X' || short === '-o' || short === '-m' ||
              short === '-c' || short === '-w' || short === '-x' ||
              short === '-U' || short === '-D' || short === '-T') {
            // Re-insert as separate tokens to process on next iterations
            tokens.splice(i + 1, 0, short, tokens[i + 1] || '');
            // We'll skip current token and process the spliced ones
            allNoArg = false;
          }
        }
        // Individual no-arg flags are just skipped
      }
      if (allNoArg) {
        // All were no-arg flags, nothing to do
      }
    } else if (!tok.startsWith('-')) {
      url = tok;
    }

    i++;
  }

  // Infer method if not set
  if (!method) {
    method = body ? 'POST' : 'GET';
  }

  // Detect body type
  if (body) {
    const ctHeader = headers.find(h => h.key.toLowerCase() === 'content-type');
    const ct = ctHeader ? ctHeader.value.toLowerCase() : '';

    if (ct.includes('application/json') || isJsonLike(body)) {
      bodyType = 'json';
    } else {
      bodyType = 'raw';
    }
  }

  return { method, url, headers, body, bodyType };
}

function isJsonLike(s) {
  const trimmed = s.trim();
  return (trimmed.startsWith('{') && trimmed.endsWith('}'))
    || (trimmed.startsWith('[') && trimmed.endsWith(']'));
}

/**
 * Tokenize a shell-like string, respecting:
 *   - Single quotes: 'no escaping'
 *   - Double quotes: "backslash escapes for \" \\ \$ \`"
 *   - $'...' ANSI-C quoting: \n \t \' \\ \xHH \uHHHH etc.
 *   - Backslash escaping outside quotes
 */
function tokenize(input) {
  const tokens = [];
  let i = 0;
  const len = input.length;

  while (i < len) {
    // Skip whitespace
    while (i < len && input[i] === ' ') i++;
    if (i >= len) break;

    let token = '';
    while (i < len && input[i] !== ' ') {
      const ch = input[i];

      if (ch === '$' && i + 1 < len && input[i + 1] === "'") {
        // $'...' ANSI-C quoting
        i += 2;
        while (i < len && input[i] !== "'") {
          if (input[i] === '\\' && i + 1 < len) {
            const esc = input[i + 1];
            if (esc === 'n') { token += '\n'; i += 2; }
            else if (esc === 't') { token += '\t'; i += 2; }
            else if (esc === 'r') { token += '\r'; i += 2; }
            else if (esc === 'a') { token += '\x07'; i += 2; }
            else if (esc === 'b') { token += '\b'; i += 2; }
            else if (esc === 'f') { token += '\f'; i += 2; }
            else if (esc === 'v') { token += '\v'; i += 2; }
            else if (esc === '\\') { token += '\\'; i += 2; }
            else if (esc === "'") { token += "'"; i += 2; }
            else if (esc === '"') { token += '"'; i += 2; }
            else if (esc === 'x' && i + 3 < len) {
              token += String.fromCharCode(parseInt(input.substring(i + 2, i + 4), 16));
              i += 4;
            } else if (esc === 'u' && i + 5 < len) {
              token += String.fromCodePoint(parseInt(input.substring(i + 2, i + 6), 16));
              i += 6;
            } else if (esc === 'U' && i + 9 < len) {
              token += String.fromCodePoint(parseInt(input.substring(i + 2, i + 10), 16));
              i += 10;
            } else if (esc >= '0' && esc <= '7') {
              // Octal: up to 3 digits
              let oct = '';
              let j = i + 1;
              while (j < len && j < i + 4 && input[j] >= '0' && input[j] <= '7') {
                oct += input[j++];
              }
              token += String.fromCharCode(parseInt(oct, 8));
              i = j;
            } else {
              token += esc;
              i += 2;
            }
          } else {
            token += input[i++];
          }
        }
        i++; // skip closing '
      } else if (ch === "'") {
        // Single-quoted string: no escaping inside
        i++;
        while (i < len && input[i] !== "'") {
          token += input[i++];
        }
        i++; // skip closing quote
      } else if (ch === '"') {
        // Double-quoted string: handle backslash escapes
        i++;
        while (i < len && input[i] !== '"') {
          if (input[i] === '\\' && i + 1 < len) {
            const next = input[i + 1];
            if (next === '"' || next === '\\' || next === '$' || next === '`' || next === '\n') {
              token += next;
              i += 2;
              continue;
            }
          }
          token += input[i++];
        }
        i++; // skip closing quote
      } else if (ch === '\\' && i + 1 < len) {
        token += input[++i];
        i++;
      } else {
        token += ch;
        i++;
      }
    }

    if (token) tokens.push(token);
  }

  return tokens;
}
