module("luci.controller.vipin", package.seeall)

require("luci.model.uci")

local i18n = {
    en = {
        title = "ViPiN Firmware",
        status = "Status",
        version = "Version",
        current_version = "Current Version",
        latest_version = "Latest Version",
        up_to_date = "Up to date",
        update_available = "Update available",
        check_update = "Check Update",
        checking = "Checking...",
        last_check = "Last checked",
        never = "Never",
        model = "Router Model",
        unknown = "Unknown",
        language = "Language",
        select_language = "Select Language",
        update_now = "Update Now",
        download = "Download",
        release_notes = "Release Notes",
        refresh = "Refresh",
        failed = "Failed",
        success = "Success",
        error = "Error",
        network_error = "Network error"
    },
    ["zh-CN"] = {
        title = "ViPiN 固件",
        status = "状态",
        version = "版本",
        current_version = "当前版本",
        latest_version = "最新版本",
        up_to_date = "已是最新版本",
        update_available = "发现新版本",
        check_update = "检查更新",
        checking = "检查中...",
        last_check = "上次检查",
        never = "从未",
        model = "路由器型号",
        unknown = "未知",
        language = "语言",
        select_language = "选择语言",
        update_now = "立即更新",
        download = "下载",
        release_notes = "更新说明",
        refresh = "刷新",
        failed = "失败",
        success = "成功",
        error = "错误",
        network_error = "网络错误"
    },
    ["zh-TW"] = {
        title = "ViPiN 固件",
        status = "狀態",
        version = "版本",
        current_version = "當前版本",
        latest_version = "最新版本",
        up_to_date = "已是最新版本",
        update_available = "發現新版本",
        check_update = "檢查更新",
        checking = "檢查中...",
        last_check = "上次檢查",
        never = "從未",
        model = "路由器型號",
        unknown = "未知",
        language = "語言",
        select_language = "選擇語言",
        update_now = "立即更新",
        download = "下載",
        release_notes = "更新說明",
        refresh = "刷新",
        failed = "失敗",
        success = "成功",
        error = "錯誤",
        network_error = "網路錯誤"
    },
    ja = {
        title = "ViPiN ファームウェア",
        status = "状態",
        version = "バージョン",
        current_version = "現在のバージョン",
        latest_version = "最新バージョン",
        up_to_date = "最新です",
        update_available = "新しいバージョンがあります",
        check_update = "更新を確認",
        checking = "確認中...",
        last_check = "最終確認",
        never = "なし",
        model = "라우터 モデル",
        unknown = "不明",
        language = "言語",
        select_language = "言語を選択",
        update_now = "今すぐ更新",
        download = "ダウンロード",
        release_notes = "リリースノート",
        refresh = "更新",
        failed = "失敗",
        success = "成功",
        error = "エラー",
        network_error = "ネットワークエラー"
    },
    ko = {
        title = "ViPiN 펌웨어",
        status = "상태",
        version = "버전",
        current_version = "현재 버전",
        latest_version = "최신 버전",
        up_to_date = "최신 상태입니다",
        update_available = "새 버전을 사용할 수 있습니다",
        check_update = "업데이트 확인",
        checking = "확인 중...",
        last_check = "마지막 확인",
        never = "없음",
        model = "라우터 모델",
        unknown = "알 수 없음",
        language = "언어",
        select_language = "언어 선택",
        update_now = "지금 업데이트",
        download = "다운로드",
        release_notes = "릴리스 노트",
        refresh = "새로고침",
        failed = "실패",
        success = "성공",
        error = "오류",
        network_error = "네트워크 오류"
    },
    ru = {
        title = "ViPiN Прошивка",
        status = "Статус",
        version = "Версия",
        current_version = "Текущая версия",
        latest_version = "Последняя версия",
        up_to_date = "У вас последняя версия",
        update_available = "Доступна новая версия",
        check_update = "Проверить обновления",
        checking = "Проверка...",
        last_check = "Последняя проверка",
        never = "Никогда",
        model = "Модель роутера",
        unknown = "Неизвестно",
        language = "Язык",
        select_language = "Выберите язык",
        update_now = "Обновить сейчас",
        download = "Скачать",
        release_notes = "Заметки о выпуске",
        refresh = "Обновить",
        failed = "Ошибка",
        success = "Успех",
        error = "Ошибка",
        network_error = "Ошибка сети"
    },
    es = {
        title = "ViPiN Firmware",
        status = "Estado",
        version = "Versión",
        current_version = "Versión actual",
        latest_version = "Última versión",
        up_to_date = "Está actualizado",
        update_available = "Nueva versión disponible",
        check_update = "Buscar actualizaciones",
        checking = "Buscando...",
        last_check = "Última comprobación",
        never = "Nunca",
        model = "Modelo de router",
        unknown = "Desconocido",
        language = "Idioma",
        select_language = "Seleccionar idioma",
        update_now = "Actualizar ahora",
        download = "Descargar",
        release_notes = "Notas de la versión",
        refresh = "Actualizar",
        failed = "Fallido",
        success = "Éxito",
        error = "Error",
        network_error = "Error de red"
    },
    de = {
        title = "ViPiN Firmware",
        status = "Status",
        version = "Version",
        current_version = "Aktuelle Version",
        latest_version = "Neueste Version",
        up_to_date = "Sie sind auf dem neuesten Stand",
        update_available = "Neue Version verfügbar",
        check_update = "Nach Updates suchen",
        checking = "Suche...",
        last_check = "Letzte Prüfung",
        never = "Nie",
        model = "Router-Modell",
        unknown = "Unbekannt",
        language = "Sprache",
        select_language = "Sprache auswählen",
        update_now = "Jetzt aktualisieren",
        download = "Herunterladen",
        release_notes = "Versionshinweise",
        refresh = "Aktualisieren",
        failed = "Fehlgeschlagen",
        success = "Erfolg",
        error = "Fehler",
        network_error = "Netzwerkfehler"
    },
    fr = {
        title = "ViPiN Firmware",
        status = "Statut",
        version = "Version",
        current_version = "Version actuelle",
        latest_version = "Dernière version",
        up_to_date = "Vous êtes à jour",
        update_available = "Nouvelle version disponible",
        check_update = "Vérifier les mises à jour",
        checking = "Vérification...",
        last_check = "Dernière vérification",
        never = "Jamais",
        model = "Modèle de routeur",
        unknown = "Inconnu",
        language = "Langue",
        select_language = "Sélectionner la langue",
        update_now = "Mettre à jour maintenant",
        download = "Télécharger",
        release_notes = "Notes de version",
        refresh = "Actualiser",
        failed = "Échoué",
        success = "Succès",
        error = "Erreur",
        network_error = "Erreur réseau"
    },
    pt = {
        title = "ViPiN Firmware",
        status = "Status",
        version = "Versão",
        current_version = "Versão atual",
        latest_version = "Última versão",
        up_to_date = "Você está atualizado",
        update_available = "Nova versão disponível",
        check_update = "Verificar atualizações",
        checking = "Verificando...",
        last_check = "Última verificação",
        never = "Nunca",
        model = "Modelo do roteador",
        unknown = "Desconhecido",
        language = "Idioma",
        select_language = "Selecionar idioma",
        update_now = "Atualizar agora",
        download = "Baixar",
        release_notes = "Notas de versão",
        refresh = "Atualizar",
        failed = "Falhou",
        success = "Sucesso",
        error = "Erro",
        network_error = "Erro de rede"
    },
    vi = {
        title = "ViPiN Firmware",
        status = "Trạng thái",
        version = "Phiên bản",
        current_version = "Phiên bản hiện tại",
        latest_version = "Phiên bản mới nhất",
        up_to_date = "Bạn đã cập nhật",
        update_available = "Phiên bản mới có sẵn",
        check_update = "Kiểm tra cập nhật",
        checking = "Đang kiểm tra...",
        last_check = "Lần kiểm tra cuối",
        never = "Chưa bao giờ",
        model = "Mẫu router",
        unknown = "Không xác định",
        language = "Ngôn ngữ",
        select_language = "Chọn ngôn ngữ",
        update_now = "Cập nhật ngay",
        download = "Tải xuống",
        release_notes = "Ghi chú phát hành",
        refresh = "Làm mới",
        failed = "Thất bại",
        success = "Thành công",
        error = "Lỗi",
        network_error = "Lỗi mạng"
    },
    th = {
        title = "ViPiN Firmware",
        status = "สถานะ",
        version = "เวอร์ชัน",
        current_version = "เวอร์ชันปัจจุบัน",
        latest_version = "เวอร์ชันล่าสุด",
        up_to_date = "คุณเป็นปัจจุบันแล้ว",
        update_available = "มีเวอร์ชันใหม่",
        check_update = "ตรวจสอบการอัปเดต",
        checking = "กำลังตรวจสอบ...",
        last_check = "ตรวจสอบล่าสุด",
        never = "ไม่เคย",
        model = "รุ่น router",
        unknown = "ไม่ทราบ",
        language = "ภาษา",
        select_language = "เลือกภาษา",
        update_now = "อัปเดตเลย",
        download = "ดาวน์โหลด",
        release_notes = "บันทึกประจำรุ่น",
        refresh = "รีเฟรช",
        failed = "ล้มเหลว",
        success = "สำเร็จ",
        error = "ข้อผิดพลาด",
        network_error = "ข้อผิดพลาดเครือข่าย"
    },
    id = {
        title = "ViPiN Firmware",
        status = "Status",
        version = "Versi",
        current_version = "Versi saat ini",
        latest_version = "Versi terbaru",
        up_to_date = "Anda sudah yang terbaru",
        update_available = "Versi baru tersedia",
        check_update = "Periksa pembaruan",
        checking = "Memeriksa...",
        last_check = "Terakhir diperiksa",
        never = "Tidak pernah",
        model = "Model router",
        unknown = "Tidak dikenal",
        language = "Bahasa",
        select_language = "Pilih bahasa",
        update_now = "Perbarui sekarang",
        download = "Unduh",
        release_notes = "Catatan rilis",
        refresh = "Segarkan",
        failed = "Gagal",
        success = "Berhasil",
        error = "Kesalahan",
        network_error = "Kesalahan jaringan"
    },
    ar = {
        title = "ViPiN البرامج الثابتة",
        status = "الحالة",
        version = "الإصدار",
        current_version = "الإصدار الحالي",
        latest_version = "أحدث إصدار",
        up_to_date = "أنت على أحدث إصدار",
        update_available = "الإصدار الجديد متاح",
        check_update = "التحقق من التحديثات",
        checking = "جارٍ التحقق...",
        last_check = "آخر فحص",
        never = "أبداً",
        model = "طراز الراوتر",
        unknown = "غير معروف",
        language = "اللغة",
        select_language = "اختر اللغة",
        update_now = "التحديث الآن",
        download = "التحميل",
        release_notes = "ملاحظات الإصدار",
        refresh = "تحديث",
        failed = "فشل",
        success = "نجاح",
        error = "خطأ",
        network_error = "خطأ في الشبكة"
    },
    fa = {
        title = "ViPiN فریمور",
        status = "وضعیت",
        version = "نسخه",
        current_version = "نسخه فعلی",
        latest_version = "آخرین نسخه",
        up_to_date = "شما به روز هستید",
        update_available = "نسخه جدید موجود است",
        check_update = "بررسی به‌روزرسانی",
        checking = "در حال بررسی...",
        last_check = "آخرین بررسی",
        never = "هرگز",
        model = "مدل روتر",
        unknown = "ناشناخته",
        language = "زبان",
        select_language = "انتخاب زبان",
        update_now = "به‌روزرسانی حالا",
        download = "دانلود",
        release_notes = "یادداشت‌های انتشار",
        refresh = "تازه‌سازی",
        failed = "ناموفق",
        success = "موفق",
        error = "خطا",
        network_error = "خطای شبکه"
    },
    hi = {
        title = "ViPiN फर्मवेयर",
        status = "स्थिति",
        version = "संस्करण",
        current_version = "वर्तमान संस्करण",
        latest_version = "नवीनतम संस्करण",
        up_to_date = "आप अद्यतन हैं",
        update_available = "नया संस्करण उपलब्ध",
        check_update = "अपडेट जांचें",
        checking = "जांच रहा है...",
        last_check = "अंतिम जांच",
        never = "कभी नहीं",
        model = "राउटर मॉडल",
        unknown = "अज्ञात",
        language = "भाषा",
        select_language = "भाषा चुनें",
        update_now = "अभी अपडेट करें",
        download = "डाउनलोड",
        release_notes = "रिलीज नोट्स",
        refresh = "रीफ्रेश",
        failed = "विफल",
        success = "सफल",
        error = "त्रुटि",
        network_error = "नेटवर्क त्रुटि"
    },
    tr = {
        title = "ViPiN Yazılım",
        status = "Durum",
        version = "Sürüm",
        current_version = "Mevcut sürüm",
        latest_version = "En son sürüm",
        up_to_date = "Güncel durumdasınız",
        update_available = "Yeni sürüm mevcut",
        check_update = "Güncellemeleri kontrol et",
        checking = "Kontrol ediliyor...",
        last_check = "Son kontrol",
        never = "Hiçbir zaman",
        model = "Yönlendirici modeli",
        unknown = "Bilinmiyor",
        language = "Dil",
        select_language = "Dil seçin",
        update_now = "Şimdi güncelle",
        download = "İndir",
        release_notes = "Sürüm notları",
        refresh = "Yenile",
        failed = "Başarısız",
        success = "Başarılı",
        error = "Hata",
        network_error = "Ağ hatası"
    }
}


function get_lang()
    local lang = nixio.fs.readfile("/etc/vipin_lang")
    if not lang or lang == "" then
        lang = "en"
    end
    return lang
end

function set_lang(lang)
    if i18n[lang] then
        nixio.fs.writefile("/etc/vipin_lang", lang)
        return true
    end
    return false
end

function get_current_version()
    local version = nixio.fs.readfile("/etc/vipin_version")
    if not version then
        version = "0"
    end
    return version:gsub("%s+", "")
end

function get_model()
    local model = nixio.fs.readfile("/etc/vipin_model")
    if not model then
        model = "Unknown"
    end
    return model:gsub("%s+", "")
end

function index()
    entry({"admin", "system", "vipin"}, alias("admin", "system", "vipin", "status"), "ViPiN").dependent = false
    local lang = get_lang and get_lang() or "en"
    entry({"admin", "system", "vipin", "status"}, template("vipin/status"), i18n[lang] and i18n[lang].title or "ViPiN Firmware", 10)
    entry({"admin", "system", "vipin", "api"}, call("api_get_status"), nil, 20)
    entry({"admin", "system", "vipin", "api_check"}, call("api_check_update"), nil, 21)
    entry({"admin", "system", "vipin", "api_set_lang"}, call("api_set_language"), nil, 22)
end

function api_get_status()
    local http = require("luci.http")
    local json = require("cjson")
    
    local status = {
        version = get_current_version(),
        model = get_model(),
        lang = get_lang(),
        update = luci.model.uci:get("system", "@system[0]", "vipin_update") or "",
        update_url = luci.model.uci:get("system", "@system[0]", "vipin_update_url") or "",
        translations = i18n[get_lang()] or i18n["en"]
    }
    
    http.prepare_content("application/json")
    http.write(json.encode(status))
end

function api_check_update()
    local http = require("luci.http")
    local json = require("cjson")
    local util = require("luci.util")
    
    local model = get_model()
    local api_url = "https://www.anyfq.com/api/v1/router/version/" .. model
    local response = util.exec("curl -s '" .. api_url .. "'")
    
    local result = {success = false}
    
    if response and response ~= "" then
        local latest = string.match(response, '"version":"([^"]+)"')
        local download_url = string.match(response, '"downloadUrl":"([^"]+)"')
        local build_id = string.match(response, '"buildId":"([^"]+)"')
        
        if latest then
            result.success = true
            result.latest_version = latest
            result.current_version = get_current_version()
            result.update_available = (latest ~= result.current_version)
            result.download_url = download_url or ""
            result.build_id = build_id or ""
        end
    end
    
    http.prepare_content("application/json")
    http.write(json.encode(result))
end

function api_set_language()
    local http = require("luci.http")
    local json = require("cjson")
    
    local params = http.getenv("QUERY_STRING") or ""
    local lang = http.formvalue("lang") or "en"
    
    local success = set_lang(lang)
    
    http.prepare_content("application/json")
    http.write(json.encode({success = success, lang = lang}))
end
