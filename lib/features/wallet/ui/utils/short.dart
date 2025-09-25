String shortAddr(String s, {int head = 6, int tail = 4}) {
  if (s.isEmpty || s.length <= head + tail + 3) return s;
  return '${s.substring(0, head)}…${s.substring(s.length - tail)}';
}