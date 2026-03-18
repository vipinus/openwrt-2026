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
        release_notes = "Release Notes",
        download_url = "Download URL",
        build_id = "Build ID",
        build_time = "Build Time",
        changelog = "Changelog"
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
        release_notes = "更新说明",
        download_url = "下载链接",
        build_id = "构建ID",
        build_time = "构建时间",
        changelog = "更新日志"
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
        release_notes = "更新說明",
        download_url = "下載連結",
        build_id = "構建ID",
        build_time = "構建時間",
        changelog = "更新日誌"
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
        model = "라우터 模型",
        unknown = "不明",
        language = "言語",
        select_language = "言語を選択",
        update_now = "今すぐ更新",
        release_notes = "リリースノート",
        download_url = "ダウンロードURL",
        build_id = "ビルドID",
        build_time = "ビルド時間",
        changelog = "変更ログ"
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
        release_notes = "릴리스 노트",
        download_url = "다운로드 URL",
        build_id = "빌드 ID",
        build_time = "빌드 시간",
        changelog = "변경 로그"
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
        release_notes = "Заметки о выпуске",
        download_url = "URL для скачивания",
        build_id = "ID сборки",
        build_time = "Время сборки",
        changelog = "Журнал изменений"
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
    entry({"admin", "system", "vipin", "status"}, form("vipin/status"), i18n[get_lang()].title, 10)
    entry({"admin", "system", "vipin", "api"}, call("api_get_status"), nil, 20)
    entry({"admin", "system", "vipin", "api_check"}, call("api_check_update"), nil, 21)
    entry({"admin", "system", "vipin", "api_set_lang"}, call("api_set_language"), nil, 22)
end

function api_get_status()
    local http = require("luci.http")
    local json = require("luci.json")
    
    local status = {
        version = get_current_version(),
        model = get_model(),
        lang = get_lang(),
        update = luci.model.uci:get("system", "@system[0]", "vipin_update") or "",
        update_url = luci.model.uci:get("system", "@system[0]", "vipin_update_url") or ""
    }
    
    http.prepare_content("application/json")
    http.write(json.encode(status))
end

function api_check_update()
    local http = require("luci.http")
    local json = require("luci.json")
    local util = require("luci.util")
    
    local model = get_model()
    local http_utils = require("luci.http.utils")
    
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
    local json = require("luci.json")
    
    local params = http.getenv("QUERY_STRING") or ""
    local lang = http.formvalue("lang") or "en"
    
    local success = set_lang(lang)
    
    http.prepare_content("application/json")
    http.write(json.encode({success = success, lang = lang}))
end
