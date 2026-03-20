require("luci.sys")
require("luci.i18n")

local m = Map("dnscrypt", translate("DNSCrypt Proxy"), translate("Encrypted DNS proxy supporting DNSCrypt and DNS-over-HTTPS protocols."))

local lang = "en"
local f = io.open("/etc/vipin_lang", "r")
if f then
    lang = f:read("*all"):match("^%s*(.-)%s*$")
    f:close()
end
if lang == "" then lang = "en" end

local i18n = {
    en = {
        enabled = "Enabled",
        listen_addr = "Listen Address",
        listen_port = "Listen Port",
        ipv4_servers = "IPv4 Servers",
        ipv6_servers = "IPv6 Servers",
        log_level = "Log Level",
        actions = "Actions",
        update_now = "Update Now",
        restart = "Restart",
        debug = "Debug",
        info = "Info",
        warning = "Warning",
        error = "Error",
        description = "All DNS queries are encrypted and routed through secure resolvers."
    },
    ["zh-CN"] = {
        enabled = "启用",
        listen_addr = "监听地址",
        listen_port = "监听端口",
        ipv4_servers = "IPv4服务器",
        ipv6_servers = "IPv6服务器",
        log_level = "日志级别",
        actions = "操作",
        update_now = "立即更新",
        restart = "重启",
        debug = "调试",
        info = "信息",
        warning = "警告",
        error = "错误",
        description = "所有DNS查询均已加密并通过安全解析器路由。"
    },
    ["zh-TW"] = {
        enabled = "啟用",
        listen_addr = "監聽位址",
        listen_port = "監聽連接埠",
        ipv4_servers = "IPv4伺服器",
        ipv6_servers = "IPv6伺服器",
        log_level = "日誌級別",
        actions = "操作",
        update_now = "立即更新",
        restart = "重新啟動",
        debug = "除錯",
        info = "資訊",
        warning = "警告",
        error = "錯誤",
        description = "所有DNS查詢均已加密並通過安全解析器路由。"
    },
    ja = {
        enabled = "有効",
        listen_addr = "待ち受けアドレス",
        listen_port = "待ち受けポート",
        ipv4_servers = "IPv4サーバー",
        ipv6_servers = "IPv6サーバー",
        log_level = "ログレベル",
        actions = "アクション",
        update_now = "今すぐ更新",
        restart = "再起動",
        debug = "デバッグ",
        info = "情報",
        warning = "警告",
        error = "エラー",
        description = "すべてのDNSクエリは暗号化され、安全なリゾルバを通じてルーティングされます。"
    },
    ko = {
        enabled = "활성화",
        listen_addr = "수신 주소",
        listen_port = "수신 포트",
        ipv4_servers = "IPv4 서버",
        ipv6_servers = "IPv6 서버",
        log_level = "로그 레벨",
        actions = "작업",
        update_now = "지금 업데이트",
        restart = "재시작",
        debug = "디버그",
        info = "정보",
        warning = "경고",
        error = "오류",
        description = "모든 DNS 쿼리는 암호화되어 보안 리졸버를 통해 라우팅됩니다."
    },
    de = {
        enabled = "Aktiviert",
        listen_addr = "Empfangsadresse",
        listen_port = "Empfangsport",
        ipv4_servers = "IPv4-Server",
        ipv6_servers = "IPv6-Server",
        log_level = "Protokollebene",
        actions = "Aktionen",
        update_now = "Jetzt aktualisieren",
        restart = "Neustart",
        debug = "Debug",
        info = "Info",
        warning = "Warnung",
        error = "Fehler",
        description = "Alle DNS-Abfragen werden verschluesselt und ueber sichere Resolver geleitet."
    },
    fr = {
        enabled = "Active",
        listen_addr = "Adresse d'ecoute",
        listen_port = "Port d'ecoute",
        ipv4_servers = "Serveurs IPv4",
        ipv6_servers = "Serveurs IPv6",
        log_level = "Niveau de log",
        actions = "Actions",
        update_now = "Mettre a jour maintenant",
        restart = "Redemarrer",
        debug = "Debug",
        info = "Info",
        warning = "Avertissement",
        error = "Erreur",
        description = "Toutes les requetes DNS sont chiffrees et routées via des resolvers securises."
    },
    es = {
        enabled = "Habilitado",
        listen_addr = "Direccion de escucha",
        listen_port = "Puerto de escucha",
        ipv4_servers = "Servidores IPv4",
        ipv6_servers = "Servidores IPv6",
        log_level = "Nivel de registro",
        actions = "Acciones",
        update_now = "Actualizar ahora",
        restart = "Reiniciar",
        debug = "Depurar",
        info = "Informacion",
        warning = "Advertencia",
        error = "Error",
        description = "Todas las consultas DNS estan cifradas y se enrutan a traves de resolutores seguros."
    },
    pt = {
        enabled = "Ativado",
        listen_addr = "Endereco de escuta",
        listen_port = "Porta de escuta",
        ipv4_servers = "Servidores IPv4",
        ipv6_servers = "Servidores IPv6",
        log_level = "Nivel de log",
        actions = "Acoes",
        update_now = "Atualizar agora",
        restart = "Reiniciar",
        debug = "Depurar",
        info = "Info",
        warning = "Aviso",
        error = "Erro",
        description = "Todas as consultas DNS sao criptografadas e roteadas por resolutores seguros."
    },
    ru = {
        enabled = "Vkljucheno",
        listen_addr = "Adres prosluhovaniya",
        listen_port = "Port prosluhovaniya",
        ipv4_servers = "IPv4 servery",
        ipv6_servers = "IPv6 servery",
        log_level = "Uroven' logirovaniya",
        actions = "Dejstviya",
        update_now = "Obnovit seychas",
        restart = "Pereзапуск",
        debug = "Otlazhka",
        info = "Info",
        warning = "Preduprezhdenie",
        error = "Oshibka",
        description = "Vse DNS-zaprosy shifruyutsya i маршрутизируются cherez bezopasnye rezolvery."
    },
    ar = {
        enabled = "مُفعَّل",
        listen_addr = "عنوان الاستماع",
        listen_port = "منفذ الاستماع",
        ipv4_servers = "خوادم IPv4",
        ipv6_servers = "خوادم IPv6",
        log_level = "مستوى السجل",
        actions = "الاجراءات",
        update_now = "تحديث الآن",
        restart = "إعادة التشغيل",
        debug = "تصحيح",
        info = "معلومات",
        warning = "تحذير",
        error = "خطأ",
        description = "يتم تشفير جميع استعلامات DNS وتوجيهها عبر محللات آمنة."
    },
    th = {
        enabled = "เปิดใช้งาน",
        listen_addr = "ที่อยู่รับฟัง",
        listen_port = "พอร์ตรับฟัง",
        ipv4_servers = "เซิร์ฟเวอร์ IPv4",
        ipv6_servers = "เซิร์ฟเวอร์ IPv6",
        log_level = "ระดับบันทึก",
        actions = "การดำเนินการ",
        update_now = "อัปเดตเดี๋ยวนี้",
        restart = "เริ่มต้นใหม่",
        debug = "ดีบัก",
        info = "ข้อมูล",
        warning = "คำเตือน",
        error = "ข้อผิดพลาด",
        description = "คำขอ DNS ทั้งหมดถูกเข้ารหัสและส่งผ่านตัวแก้ไขที่ปลอดภัย"
    },
    fa = {
        enabled = "فعال",
        listen_addr = "آدرس گوش دادن",
        listen_port = "پورت گوش دادن",
        ipv4_servers = "سرورهای IPv4",
        ipv6_servers = "سرورهای IPv6",
        log_level = "سطح لاگ",
        actions = "اقدامات",
        update_now = "بروزرسانی حالا",
        restart = "ری‌استارت",
        debug = "دیباگ",
        info = "اطلاعات",
        warning = "هشدار",
        error = "خطا",
        description = "تمام پرس‌وجوهای DNS رمزگذاری شده و از طریق وضوح‌دهنده‌های امن مسیریابی می‌شوند."
    },
    tr = {
        enabled = "Etkin",
        listen_addr = "Dinleme adresi",
        listen_port = "Dinleme portu",
        ipv4_servers = "IPv4 Sunuculari",
        ipv6_servers = "IPv6 Sunuculari",
        log_level = "Gunluk seviyesi",
        actions = "Eylemler",
        update_now = "Simdi guncelle",
        restart = "Yeniden baslat",
        debug = "Hata ayiklama",
        info = "Bilgi",
        warning = "Uyari",
        error = "Hata",
        description = "Tum DNS sorgulari sifrelenir ve guvenli cözumleyiciler uzerinden yonlendirilir."
    },
    id = {
        enabled = "Diaktifkan",
        listen_addr = "Alamat dengar",
        listen_port = "Port dengar",
        ipv4_servers = "Server IPv4",
        ipv6_servers = "Server IPv6",
        log_level = "Tingkat log",
        actions = "Aksi",
        update_now = "Perbarui sekarang",
        restart = "Mulai ulang",
        debug = "Debug",
        info = "Info",
        warning = "Peringatan",
        error = "Kesalahan",
        description = "Semua permintaan DNS Dienkripsi dan Dirute melalui resolver yang aman."
    },
    hi = {
        enabled = "सक्षम",
        listen_addr = "सुनने का पता",
        listen_port = "सुनने का पोर्ट",
        ipv4_servers = "IPv4 सर्वर",
        ipv6_servers = "IPv6 सर्वर",
        log_level = "लॉग स्तर",
        actions = "कार्रवाई",
        update_now = "अभी अपडेट करें",
        restart = "पुनः आरंभ करें",
        debug = "डीबग",
        info = "जानकारी",
        warning = "चेतावनी",
        error = "त्रुटि",
        description = "सभी DNS क्वेरी एन्क्रिप्ट की जाती हैं और सुरक्षित रिज़ॉल्वर्स के माध्यम से रूट की जाती हैं।"
    },
    vi = {
        enabled = "Bat",
        listen_addr = "Dia chi lang nghe",
        listen_port = "Cong lang nghe",
        ipv4_servers = "May chu IPv4",
        ipv6_servers = "May chu IPv6",
        log_level = "Cap do nhat ky",
        actions = "Hanh dong",
        update_now = "Cap nhat ngay",
        restart = "Khoi dong lai",
        debug = "Go loi",
        info = "Thong tin",
        warning = "Canh bao",
        error = "Loi",
        description = "Tat ca cac truy van DNS deu duoc ma hoa va dinh tuyen qua cac resolver an toan."
    }
}

local t = i18n[lang] or i18n["en"]

local s = m:section(TypedSection, "dnscrypt", "")
s.anonymous = true
s.addremove = false

m.description = t.description

local o = s:option(Flag, "enabled", translate(t.enabled))
o.default = "1"
o.rmempty = false

o = s:option(Value, "listen_addr", translate(t.listen_addr))
o.default = "127.0.0.1"
o.datatype = "ipaddr"

o = s:option(Value, "listen_port", translate(t.listen_port))
o.default = "5353"
o.datatype = "port"

o = s:option(Flag, "ipv4_servers", translate(t.ipv4_servers))
o.default = "1"

o = s:option(Flag, "ipv6_servers", translate(t.ipv6_servers))
o.default = "0"

o = s:option(ListValue, "log_level", translate(t.log_level))
o:value("0", translate(t.debug))
o:value("1", translate(t.info))
o:value("2", translate(t.warning))
o:value("3", translate(t.error))
o.default = "2"

local s2 = m:section(TypedSection, "dnscrypt", translate(t.actions))
s2.anonymous = true

o = s2:option(Button, "_update", translate(t.update_now))
o.inputtitle = translate(t.update_now)
o.inputstyle = "apply"

function o.write(self, section)
    luci.sys.call("/etc/init.d/dnscrypt-proxy update_servers >/dev/null 2>&1")
    luci.http.redirect(luci.dispatcher.build_url("admin/network/dnscrypt"))
end

o = s2:option(Button, "_restart", translate(t.restart))
o.inputtitle = translate(t.restart)
o.inputstyle = "reload"

function o.write(self, section)
    luci.sys.call("/etc/init.d/dnscrypt-proxy restart >/dev/null 2>&1")
    luci.http.redirect(luci.dispatcher.build_url("admin/network/dnscrypt"))
end

return m
