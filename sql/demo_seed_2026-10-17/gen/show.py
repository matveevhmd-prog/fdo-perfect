import sys, re
pid = sys.argv[1]; f = pid.replace('-', '_')
a = open('../out/05_snap_%s.sql' % f).read()
b = open('../out/06_items_%s.sql' % f).read()
b = b.replace('$q$%s$q$' % pid, "'%s'" % pid)
b = re.sub(r"\$q\$(.*?)\$q\$", lambda m: "'" + m.group(1).replace("'", "''") + "'", b)
print(a + b)
