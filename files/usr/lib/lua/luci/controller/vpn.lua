module("luci.controller.vpn", package.seeall)

require("luci.model.uci")

local i18n = {
    en = {
        title = "VPN Settings",
        vpn = "VPN",
        vpn_settings = "VPN Settings",
        vpn_status = "VPN Status",
        enabled = "Enabled",
        disabled = "Disabled",
        connecting = "Connecting",
        connected = "Connected",
        disconnected = "Disconnected",
        split_tunnel = "Split Tunneling",
        split_tunnel_desc = "Route domestic traffic directly, foreign traffic via VPN",
        vpn_server = "VPN Server",
        connect = "Connect",
        disconnect = "Disconnect",
        reconnect = "Reconnect",
        save = "Save",
        cancel = "Cancel",
        apply = "Apply",
        refresh = "Refresh",
        loading = "Loading...",
        error = "Error",
        success = "Success",
        connection_failed = "Connection failed",
        connection_success = "Connection established",
        please_wait = "Please wait...",
        checking = "Checking...",
        no_servers = "No servers available",
        server_list = "Server List",
        latency = "Latency",
        update_ip_ranges = "Update IP Ranges",
        last_updated = "Last updated",
        never = "Never",
        count = "Count",
        routes_updated = "Routes updated",
        routes_count = "routes",
        domestic_traffic = "Domestic Traffic",
        foreign_traffic = "Foreign Traffic",
        vpn_exit = "VPN Exit",
        update_now = "Update Now",
        detecting = "Detecting location...",
        detected = "Detected",
        your_ip = "Your IP",
        your_country = "Your Country",
        auto_detect = "Auto-detect",
        detected_success = "Location detected",
        detection_failed = "Detection failed",
        real_ip = "Real IP (before VPN)",
        vpn_ip = "VPN IP",
        location = "Location",
        ip_ranges_loaded = "IP ranges loaded",
        retry = "Retry",
        login = "Login",
        logout = "Logout",
        username = "Username",
        password = "Password",
        login_title = "VIP Account Login",
        login_desc = "Enter your account credentials to connect VPN",
        login_button = "Login & Connect",
        logout_button = "Logout & Disconnect",
        invalid_credentials = "Invalid username or password",
        account_expired = "Account has expired",
        not_vip_account = "This account is not a VIP account",
        logged_in = "Logged In",
        logged_out = "Not Logged In",
        expired = "Expired",
        not_vip = "Not VIP",
        login_required = "Login Required",
        user_status = "User Status",
        vip_user = "VIP User",
        valid_until = "Valid Until",
        auto_connect = "Auto-connect when VIP",
        checking_status = "Checking status..."
    },
    ["zh-CN"] = {
        title = "VPN 设置",
        vpn = "VPN",
        vpn_settings = "VPN 设置",
        vpn_status = "VPN 状态",
        enabled = "已启用",
        disabled = "已禁用",
        connecting = "连接中",
        connected = "已连接",
        disconnected = "未连接",
        split_tunnel = "智能分流",
        split_tunnel_desc = "国内IP直连，海外IP走VPN",
        vpn_server = "VPN服务器",
        connect = "连接",
        disconnect = "断开",
        reconnect = "重连",
        save = "保存",
        cancel = "取消",
        apply = "应用",
        refresh = "刷新",
        loading = "加载中...",
        error = "错误",
        success = "成功",
        connection_failed = "连接失败",
        connection_success = "连接成功",
        please_wait = "请稍候...",
        checking = "检查中...",
        no_servers = "暂无可用服务器",
        server_list = "服务器列表",
        latency = "延迟",
        update_ip_ranges = "更新IP段",
        last_updated = "上次更新",
        never = "从未",
        count = "数量",
        routes_updated = "路由已更新",
        routes_count = "条路由",
        domestic_traffic = "国内流量",
        foreign_traffic = "海外流量",
        vpn_exit = "VPN出口",
        update_now = "立即更新",
        detecting = "正在检测位置...",
        detected = "已检测",
        your_ip = "您的IP",
        your_country = "您的国家",
        auto_detect = "自动检测",
        detected_success = "位置已检测",
        detection_failed = "检测失败",
        real_ip = "真实IP（VPN前）",
        vpn_ip = "VPN IP",
        location = "位置",
        ip_ranges_loaded = "已加载IP段",
        retry = "重试",
        login = "登录",
        logout = "退出",
        username = "用户名",
        password = "密码",
        login_title = "VIP账户登录",
        login_desc = "输入您的账户凭据以连接VPN",
        login_button = "登录并连接",
        logout_button = "退出并断开",
        invalid_credentials = "用户名或密码错误",
        account_expired = "账户已过期",
        not_vip_account = "此账户不是VIP账户",
        logged_in = "已登录",
        logged_out = "未登录",
        expired = "已过期",
        not_vip = "非VIP",
        login_required = "需要登录",
        user_status = "用户状态",
        vip_user = "VIP用户",
        valid_until = "有效期至",
        auto_connect = "VIP用户自动连接",
        checking_status = "检查状态中..."
    },
    ["zh-TW"] = {
        title = "VPN 設定",
        vpn = "VPN",
        vpn_settings = "VPN 設定",
        vpn_status = "VPN 狀態",
        enabled = "已啟用",
        disabled = "已停用",
        connecting = "連線中",
        connected = "已連線",
        disconnected = "未連線",
        split_tunnel = "智慧分流",
        split_tunnel_desc = "國內IP直連，海外IP走VPN",
        domestic_ip = "國內IP段",
        domestic_ip_desc = "選擇國內IP所屬國家",
        domestic_country = "國內歸屬地",
        current_country = "目前國家",
        ip_ranges_loaded = "已載入IP段",
        vpn_server = "VPN伺服器",
        select_server = "選擇伺服器",
        connect = "連線",
        disconnect = "斷線",
        reconnect = "重連",
        save = "儲存",
        cancel = "取消",
        apply = "套用",
        refresh = "更新",
        loading = "載入中...",
        error = "錯誤",
        success = "成功",
        connection_failed = "連線失敗",
        connection_success = "連線成功",
        please_wait = "請稍候...",
        checking = "檢查中...",
        no_servers = "暫無可用伺服器",
        server_list = "伺服器列表",
        latency = "延遲",
        select_country = "選擇國家",
        update_ip_ranges = "更新IP段",
        last_updated = "上次更新",
        never = "從未",
        count = "數量",
        routes_updated = "路由已更新",
        routes_count = "條路由",
        domestic_traffic = "國內流量",
        foreign_traffic = "海外流量",
        vpn_exit = "VPN出口",
        update_now = "立即更新",
        detecting = "正在偵測位置...",
        detected = "已偵測",
        your_ip = "您的IP",
        your_country = "您的國家",
        auto_detect = "自動偵測",
        detected_success = "位置已偵測",
        detection_failed = "偵測失敗",
        real_ip = "真實IP（VPN前）",
        vpn_ip = "VPN IP",
        location = "位置",
        ip_ranges_loaded = "已載入IP段",
        retry = "重試",
        login = "登入",
        logout = "登出",
        username = "用戶名",
        password = "密碼",
        login_title = "VIP帳戶登入",
        login_desc = "輸入您的帳戶憑據以連接VPN",
        login_button = "登入並連接",
        logout_button = "登出並斷開",
        invalid_credentials = "用戶名或密碼錯誤",
        account_expired = "帳戶已過期",
        not_vip_account = "此帳戶不是VIP帳戶",
        logged_in = "已登入",
        logged_out = "未登入",
        expired = "已過期",
        not_vip = "非VIP",
        login_required = "需要登入",
        user_status = "用戶狀態",
        vip_user = "VIP用戶",
        valid_until = "有效期至",
        auto_connect = "VIP用戶自動連接",
        checking_status = "檢查狀態中..."
    },
    ja = {
        title = "VPN 設定",
        vpn = "VPN",
        vpn_settings = "VPN 設定",
        vpn_status = "VPN 状態",
        enabled = "有効",
        disabled = "無効",
        connecting = "接続中",
        connected = "接続済み",
        disconnected = "未接続",
        split_tunnel = "スプリットトンネリング",
        split_tunnel_desc = "国内IPは直接、海外IPはVPN経由",
        domestic_ip = "国内IP",
        domestic_ip_desc = "国内IPの所属国を選択",
        domestic_country = "国内所在地",
        current_country = "現在の国",
        ip_ranges_loaded = "読み込み済みIP",
        vpn_server = "VPNサーバー",
        select_server = "サーバー選択",
        connect = "接続",
        disconnect = "切断",
        reconnect = "再接続",
        save = "保存",
        cancel = "キャンセル",
        apply = "適用",
        refresh = "更新",
        loading = "読み込み中...",
        error = "エラー",
        success = "成功",
        connection_failed = "接続失敗",
        connection_success = "接続成功",
        please_wait = "お待ちください...",
        checking = "確認中...",
        no_servers = "利用可能なサーバーなし",
        server_list = "サーバー一覧",
        latency = "遅延",
        select_country = "国を選択",
        update_ip_ranges = "IP更新",
        last_updated = "最終更新",
        never = "なし",
        count = "数",
        routes_updated = "ルート更新済み",
        routes_count = "ルート",
        domestic_traffic = "国内トラフィック",
        foreign_traffic = "海外トラフィック",
        vpn_exit = "VPN出口",
        update_now = "今すぐ更新",
        detecting = "位置を検出中...",
        detected = "検出済み",
        your_ip = "あなたのIP",
        your_country = "あなたの国",
        auto_detect = "自動検出",
        detected_success = "位置を検出しました",
        detection_failed = "検出に失敗しました",
        real_ip = "実際のIP",
        vpn_ip = "VPN IP",
        location = "位置",
        ip_ranges_loaded = "IP読み込み済み",
        retry = "再試行",
        login = "ログイン",
        logout = "ログアウト",
        username = "ユーザー名",
        password = "パスワード",
        login_title = "VIPアカウントログイン",
        login_desc = "アカウント資格情報を入力してVPNに接続",
        login_button = "ログイン＆接続",
        logout_button = "ログアウト＆切断",
        invalid_credentials = "ユーザー名またはパスワードが正しくありません",
        account_expired = "アカウント期限切れ",
        not_vip_account = "このアカウントはVIPアカウントではありません",
        logged_in = "ログイン済み",
        logged_out = "未ログイン",
        expired = "期限切れ",
        not_vip = "VIPではない",
        login_required = "ログイン必要",
        user_status = "ユーザー状態",
        vip_user = "VIPユーザー",
        valid_until = "有効期限",
        auto_connect = "VIPユーザーは自動接続",
        checking_status = "状態確認中..."
    },
    ko = {
        title = "VPN 설정",
        vpn = "VPN",
        vpn_settings = "VPN 설정",
        vpn_status = "VPN 상태",
        enabled = "활성화됨",
        disabled = "비활성화됨",
        connecting = "연결 중",
        connected = "연결됨",
        disconnected = "연결 안됨",
        split_tunnel = "스플릿 터널링",
        split_tunnel_desc = "국내 IP는 직접, 해외 IP는 VPN 경유",
        domestic_ip = "국내 IP",
        domestic_ip_desc = "국내 IP 국가 선택",
        domestic_country = "국내 위치",
        current_country = "현재 국가",
        ip_ranges_loaded = "로드된 IP",
        vpn_server = "VPN 서버",
        select_server = "서버 선택",
        connect = "연결",
        disconnect = "연결 해제",
        reconnect = "재연결",
        save = "저장",
        cancel = "취소",
        apply = "적용",
        refresh = "새로고침",
        loading = "로딩 중...",
        error = "오류",
        success = "성공",
        connection_failed = "연결 실패",
        connection_success = "연결 성공",
        please_wait = "기다려 주세요...",
        checking = "확인 중...",
        no_servers = "사용 가능한 서버 없음",
        server_list = "서버 목록",
        latency = "지연",
        select_country = "국가 선택",
        update_ip_ranges = "IP 업데이트",
        last_updated = "마지막 업데이트",
        never = "없음",
        count = "개수",
        routes_updated = "경로 업데이트됨",
        routes_count = "경로",
        domestic_traffic = "국내 트래픽",
        foreign_traffic = "해외 트래픽",
        vpn_exit = "VPN 출구",
        update_now = "지금 업데이트",
        detecting = "위치 감지 중...",
        detected = "감지됨",
        your_ip = "내 IP",
        your_country = "내 국가",
        auto_detect = "자동 감지",
        detected_success = "위치 감지됨",
        detection_failed = "감지 실패",
        real_ip = "실제 IP",
        vpn_ip = "VPN IP",
        location = "위치",
        ip_ranges_loaded = "IP 로드됨",
        retry = "다시 시도",
        login = "로그인",
        logout = "로그아웃",
        username = "사용자 이름",
        password = "비밀번호",
        login_title = "VIP 계정 로그인",
        login_desc = "VPN 연결을 위한 계정 자격 증명 입력",
        login_button = "로그인 및 연결",
        logout_button = "로그아웃 및 연결 해제",
        invalid_credentials = "사용자 이름 또는 비밀번호가 올바르지 않습니다",
        account_expired = "계정이 만료되었습니다",
        not_vip_account = "이 계정은 VIP 계정이 아닙니다",
        logged_in = "로그인됨",
        logged_out = "미로그인",
        expired = "만료됨",
        not_vip = "VIP 아님",
        login_required = "로그인 필요",
        user_status = "사용자 상태",
        vip_user = "VIP 사용자",
        valid_until = "유효 기간",
        auto_connect = "VIP 사용자 자동 연결",
        checking_status = "상태 확인 중..."
    },
    ru = {
        title = "Настройки VPN",
        vpn = "VPN",
        vpn_settings = "Настройки VPN",
        vpn_status = "Статус VPN",
        enabled = "Включено",
        disabled = "Отключено",
        connecting = "Подключение",
        connected = "Подключено",
        disconnected = "Отключено",
        split_tunnel = "Раздельное туннелирование",
        split_tunnel_desc = "Локальный трафик напрямую, зарубежный через VPN",
        domestic_ip = "Локальные IP",
        domestic_ip_desc = "Выберите страну для локальных IP",
        domestic_country = "Локальная страна",
        current_country = "Текущая страна",
        ip_ranges_loaded = "Загружено IP",
        vpn_server = "VPN сервер",
        select_server = "Выбрать сервер",
        connect = "Подключить",
        disconnect = "Отключить",
        reconnect = "Переподключить",
        save = "Сохранить",
        cancel = "Отмена",
        apply = "Применить",
        refresh = "Обновить",
        loading = "Загрузка...",
        error = "Ошибка",
        success = "Успех",
        connection_failed = "Ошибка подключения",
        connection_success = "Подключено",
        please_wait = "Пожалуйста, подождите...",
        checking = "Проверка...",
        no_servers = "Нет доступных серверов",
        server_list = "Список серверов",
        latency = "Задержка",
        select_country = "Выберите страну",
        update_ip_ranges = "Обновить IP",
        last_updated = "Последнее обновление",
        never = "Никогда",
        count = "Количество",
        routes_updated = "Маршруты обновлены",
        routes_count = "маршрутов",
        domestic_traffic = "Местный трафик",
        foreign_traffic = "Зарубежный трафик",
        vpn_exit = "VPN выход",
        update_now = "Обновить сейчас",
        detecting = "Определение местоположения...",
        detected = "Определено",
        your_ip = "Ваш IP",
        your_country = "Ваша страна",
        auto_detect = "Автоопределение",
        detected_success = "Местоположение определено",
        detection_failed = "Не удалось определить",
        real_ip = "Реальный IP",
        vpn_ip = "VPN IP",
        location = "Местоположение",
        ip_ranges_loaded = "IP загружены",
        retry = "Повторить",
        login = "Войти",
        logout = "Выйти",
        username = "Имя пользователя",
        password = "Пароль",
        login_title = "Вход VIP аккаунт",
        login_desc = "Введите данные аккаунта для подключения VPN",
        login_button = "Войти и подключить",
        logout_button = "Выйти и отключить",
        invalid_credentials = "Неверное имя пользователя или пароль",
        account_expired = "Аккаунт истёк",
        not_vip_account = "Этот аккаунт не является VIP",
        logged_in = "Авторизован",
        logged_out = "Не авторизован",
        expired = "Истёк",
        not_vip = "Не VIP",
        login_required = "Требуется вход",
        user_status = "Статус пользователя",
        vip_user = "VIP пользователь",
        valid_until = "Действителен до",
        auto_connect = "VIP автоподключение",
        checking_status = "Проверка статуса..."
    },
    es = {
        title = "Configuración VPN",
        vpn = "VPN",
        vpn_settings = "Configuración VPN",
        vpn_status = "Estado VPN",
        enabled = "Activado",
        disabled = "Desactivado",
        connecting = "Conectando",
        connected = "Conectado",
        disconnected = "Desconectado",
        split_tunnel = "Túnel dividido",
        split_tunnel_desc = "Tráfico nacional directo, extranjero por VPN",
        domestic_ip = "IPs nacionales",
        domestic_ip_desc = "Seleccionar país para IPs nacionales",
        domestic_country = "País nacional",
        current_country = "País actual",
        ip_ranges_loaded = "IPs cargadas",
        vpn_server = "Servidor VPN",
        select_server = "Seleccionar servidor",
        connect = "Conectar",
        disconnect = "Desconectar",
        reconnect = "Reconectar",
        save = "Guardar",
        cancel = "Cancelar",
        apply = "Aplicar",
        refresh = "Actualizar",
        loading = "Cargando...",
        error = "Error",
        success = "Éxito",
        connection_failed = "Conexión fallida",
        connection_success = "Conexión establecida",
        please_wait = "Por favor espere...",
        checking = "Verificando...",
        no_servers = "Sin servidores disponibles",
        server_list = "Lista de servidores",
        latency = "Latencia",
        select_country = "Seleccionar país",
        update_ip_ranges = "Actualizar IPs",
        last_updated = "Última actualización",
        never = "Nunca",
        count = "Cantidad",
        routes_updated = "Rutas actualizadas",
        routes_count = "rutas"
    },
    de = {
        title = "VPN Einstellungen",
        vpn = "VPN",
        vpn_settings = "VPN Einstellungen",
        vpn_status = "VPN Status",
        enabled = "Aktiviert",
        disabled = "Deaktiviert",
        connecting = "Verbinde",
        connected = "Verbunden",
        disconnected = "Getrennt",
        split_tunnel = "Split-Tunneling",
        split_tunnel_desc = "Inlandsverkehr direkt, Auslandsverkehr über VPN",
        domestic_ip = "Inlands IPs",
        domestic_ip_desc = "Land für Inlands IPs auswählen",
        domestic_country = "Inlandsland",
        current_country = "Aktuelles Land",
        ip_ranges_loaded = "IPs geladen",
        vpn_server = "VPN Server",
        select_server = "Server auswählen",
        connect = "Verbinden",
        disconnect = "Trennen",
        reconnect = "Neu verbinden",
        save = "Speichern",
        cancel = "Abbrechen",
        apply = "Anwenden",
        refresh = "Aktualisieren",
        loading = "Laden...",
        error = "Fehler",
        success = "Erfolg",
        connection_failed = "Verbindung fehlgeschlagen",
        connection_success = "Verbindung hergestellt",
        please_wait = "Bitte warten...",
        checking = "Prüfen...",
        no_servers = "Keine Server verfügbar",
        server_list = "Serverliste",
        latency = "Latenz",
        select_country = "Land auswählen",
        update_ip_ranges = "IPs aktualisieren",
        last_updated = "Zuletzt aktualisiert",
        never = "Nie",
        count = "Anzahl",
        routes_updated = "Routen aktualisiert",
        routes_count = "Routen"
    },
    fr = {
        title = "Paramètres VPN",
        vpn = "VPN",
        vpn_settings = "Paramètres VPN",
        vpn_status = "État du VPN",
        enabled = "Activé",
        disabled = "Désactivé",
        connecting = "Connexion",
        connected = "Connecté",
        disconnected = "Déconnecté",
        split_tunnel = "Tunneling séparé",
        split_tunnel_desc = "Trafic domestique direct, étranger via VPN",
        domestic_ip = "IPs domestiques",
        domestic_ip_desc = "Sélectionner le pays pour IPs domestiques",
        domestic_country = "Pays domestique",
        current_country = "Pays actuel",
        ip_ranges_loaded = "IPs chargées",
        vpn_server = "Serveur VPN",
        select_server = "Sélectionner serveur",
        connect = "Connecter",
        disconnect = "Déconnecter",
        reconnect = "Reconnecter",
        save = "Enregistrer",
        cancel = "Annuler",
        apply = "Appliquer",
        refresh = "Actualiser",
        loading = "Chargement...",
        error = "Erreur",
        success = "Succès",
        connection_failed = "Connexion échouée",
        connection_success = "Connexion établie",
        please_wait = "Veuillez patienter...",
        checking = "Vérification...",
        no_servers = "Aucun serveur disponible",
        server_list = "Liste des serveurs",
        latency = "Latence",
        select_country = "Sélectionner pays",
        update_ip_ranges = "Mettre à jour IPs",
        last_updated = "Dernière mise à jour",
        never = "Jamais",
        count = "Nombre",
        routes_updated = "Routes mises à jour",
        routes_count = "routes"
    },
    pt = {
        title = "Configurações VPN",
        vpn = "VPN",
        vpn_settings = "Configurações VPN",
        vpn_status = "Status VPN",
        enabled = "Ativado",
        disabled = "Desativado",
        connecting = "Conectando",
        connected = "Conectado",
        disconnected = "Desconectado",
        split_tunnel = "Túnel dividido",
        split_tunnel_desc = "Tráfego doméstico direto, estrangeiro via VPN",
        domestic_ip = "IPs domésticas",
        domestic_ip_desc = "Selecionar país para IPs domésticas",
        domestic_country = "País doméstico",
        current_country = "País atual",
        ip_ranges_loaded = "IPs carregadas",
        vpn_server = "Servidor VPN",
        select_server = "Selecionar servidor",
        connect = "Conectar",
        disconnect = "Desconectar",
        reconnect = "Reconectar",
        save = "Salvar",
        cancel = "Cancelar",
        apply = "Aplicar",
        refresh = "Atualizar",
        loading = "Carregando...",
        error = "Erro",
        success = "Sucesso",
        connection_failed = "Conexão falhou",
        connection_success = "Conexão estabelecida",
        please_wait = "Por favor aguarde...",
        checking = "Verificando...",
        no_servers = "Sem servidores disponíveis",
        server_list = "Lista de servidores",
        latency = "Latência",
        select_country = "Selecionar país",
        update_ip_ranges = "Atualizar IPs",
        last_updated = "Última atualização",
        never = "Nunca",
        count = "Quantidade",
        routes_updated = "Rotas atualizadas",
        routes_count = "rotas"
    },
    vi = {
        title = "Cài đặt VPN",
        vpn = "VPN",
        vpn_settings = "Cài đặt VPN",
        vpn_status = "Trạng thái VPN",
        enabled = "Đã bật",
        disabled = "Đã tắt",
        connecting = "Đang kết nối",
        connected = "Đã kết nối",
        disconnected = "Chưa kết nối",
        split_tunnel = "Chia tách đường hầm",
        split_tunnel_desc = "Lưu lượng trong nước trực tiếp, nước ngoài qua VPN",
        domestic_ip = "IP trong nước",
        domestic_ip_desc = "Chọn quốc gia cho IP trong nước",
        domestic_country = "Quốc gia trong nước",
        current_country = "Quốc gia hiện tại",
        ip_ranges_loaded = "Đã tải IP",
        vpn_server = "Máy chủ VPN",
        select_server = "Chọn máy chủ",
        connect = "Kết nối",
        disconnect = "Ngắt kết nối",
        reconnect = "Kết nối lại",
        save = "Lưu",
        cancel = "Hủy",
        apply = "Áp dụng",
        refresh = "Làm mới",
        loading = "Đang tải...",
        error = "Lỗi",
        success = "Thành công",
        connection_failed = "Kết nối thất bại",
        connection_success = "Kết nối thành công",
        please_wait = "Vui lòng đợi...",
        checking = "Đang kiểm tra...",
        no_servers = "Không có máy chủ khả dụng",
        server_list = "Danh sách máy chủ",
        latency = "Độ trễ",
        select_country = "Chọn quốc gia",
        update_ip_ranges = "Cập nhật IP",
        last_updated = "Cập nhật lần cuối",
        never = "Chưa bao giờ",
        count = "Số lượng",
        routes_updated = "Tuyến đường đã cập nhật",
        routes_count = "tuyến đường"
    },
    th = {
        title = "การตั้งค่า VPN",
        vpn = "VPN",
        vpn_settings = "การตั้งค่า VPN",
        vpn_status = "สถานะ VPN",
        enabled = "เปิดใช้งาน",
        disabled = "ปิดใช้งาน",
        connecting = "กำลังเชื่อมต่อ",
        connected = "เชื่อมต่อแล้ว",
        disconnected = "ยังไม่เชื่อมต่อ",
        split_tunnel = "แยกทาง",
        split_tunnel_desc = " трафик ในประเทศตรง, ต่างประเทศผ่าน VPN",
        domestic_ip = "IP ในประเทศ",
        domestic_ip_desc = "เลือกประเทศสำหรับ IP ในประเทศ",
        domestic_country = "ประเทศในประเทศ",
        current_country = "ประเทศปัจจุบัน",
        ip_ranges_loaded = "IP ที่โหลดแล้ว",
        vpn_server = "เซิร์ฟเวอร์ VPN",
        select_server = "เลือกเซิร์ฟเวอร์",
        connect = "เชื่อมต่อ",
        disconnect = "ตัดการเชื่อมต่อ",
        reconnect = "เชื่อมต่อใหม่",
        save = "บันทึก",
        cancel = "ยกเลิก",
        apply = "นำไปใช้",
        refresh = "รีเฟรช",
        loading = "กำลังโหลด...",
        error = "ข้อผิดพลาด",
        success = "สำเร็จ",
        connection_failed = "การเชื่อมต่อล้มเหลว",
        connection_success = "เชื่อมต่อสำเร็จ",
        please_wait = "โปรดรอ...",
        checking = "กำลังตรวจสอบ...",
        no_servers = "ไม่มีเซิร์ฟเวอร์ที่ใช้ได้",
        server_list = "รายการเซิร์ฟเวอร์",
        latency = "เวลาแฝง",
        select_country = "เลือกประเทศ",
        update_ip_ranges = "อัปเดต IP",
        last_updated = "อัปเดตล่าสุด",
        never = "ไม่เคย",
        count = "จำนวน",
        routes_updated = "เส้นทางอัปเดตแล้ว",
        routes_count = "เส้นทาง"
    },
    id = {
        title = "Pengaturan VPN",
        vpn = "VPN",
        vpn_settings = "Pengaturan VPN",
        vpn_status = "Status VPN",
        enabled = "Aktif",
        disabled = "Nonaktif",
        connecting = "Menghubungkan",
        connected = "Terhubung",
        disconnected = "Terputus",
        split_tunnel = "Terowongan Terpisah",
        split_tunnel_desc = "Lalu lintas dalam negeri langsung, luar negeri via VPN",
        domestic_ip = "IP Dalam Negeri",
        domestic_ip_desc = "Pilih negara untuk IP dalam negeri",
        domestic_country = "Negara Dalam Negeri",
        current_country = "Negara Saat Ini",
        ip_ranges_loaded = "IP dimuat",
        vpn_server = "Server VPN",
        select_server = "Pilih Server",
        connect = "Sambungkan",
        disconnect = "Putuskan",
        reconnect = "Sambungkan Ulang",
        save = "Simpan",
        cancel = "Batal",
        apply = "Terapkan",
        refresh = "Segarkan",
        loading = "Memuat...",
        error = "Kesalahan",
        success = "Berhasil",
        connection_failed = "Koneksi gagal",
        connection_success = "Koneksi berhasil",
        please_wait = "Silakan tunggu...",
        checking = "Memeriksa...",
        no_servers = "Tidak ada server tersedia",
        server_list = "Daftar Server",
        latency = "Latensi",
        select_country = "Pilih Negara",
        update_ip_ranges = "Perbarui IP",
        last_updated = "Terakhir diperbarui",
        never = "Tidak pernah",
        count = "Jumlah",
        routes_updated = "Rute diperbarui",
        routes_count = "rute"
    },
    ar = {
        title = "إعدادات VPN",
        vpn = "VPN",
        vpn_settings = "إعدادات VPN",
        vpn_status = "حالة VPN",
        enabled = "مفعل",
        disabled = "معطل",
        connecting = "جاري الاتصال",
        connected = "متصل",
        disconnected = "غير متصل",
        split_tunnel = "نفق منفصل",
        split_tunnel_desc = "حركة المرور المحلية مباشرة، الأجنبية عبر VPN",
        domestic_ip = "IPs المحلية",
        domestic_ip_desc = "اختر الدولة لـ IPs المحلية",
        domestic_country = "الدولة المحلية",
        current_country = "الدولة الحالية",
        ip_ranges_loaded = "تم تحميل IPs",
        vpn_server = "خادم VPN",
        select_server = "اختر الخادم",
        connect = "اتصال",
        disconnect = "قطع الاتصال",
        reconnect = "إعادة الاتصال",
        save = "حفظ",
        cancel = "إلغاء",
        apply = "تطبيق",
        refresh = "تحديث",
        loading = "جاري التحميل...",
        error = "خطأ",
        success = "نجاح",
        connection_failed = "فشل الاتصال",
        connection_success = "تم الاتصال بنجاح",
        please_wait = "الرجاء الانتظار...",
        checking = "جاري الفحص...",
        no_servers = "لا توجد خوادم متاحة",
        server_list = "قائمة الخوادم",
        latency = "زمن الاستجابة",
        select_country = "اختر الدولة",
        update_ip_ranges = "تحديث IPs",
        last_updated = "آخر تحديث",
        never = "أبداً",
        count = "العدد",
        routes_updated = "تم تحديث المسارات",
        routes_count = "مسارات"
    },
    fa = {
        title = "تنظیمات VPN",
        vpn = "VPN",
        vpn_settings = "تنظیمات VPN",
        vpn_status = "وضعیت VPN",
        enabled = "فعال",
        disabled = "غیرفعال",
        connecting = "در حال اتصال",
        connected = "متصل",
        disconnected = "قطع",
        split_tunnel = "تونل جدا",
        split_tunnel_desc = "ترافیک داخلی مستقیم، خارجی از طریق VPN",
        domestic_ip = "IP های داخلی",
        domestic_ip_desc = "کشور را برای IP های داخلی انتخاب کنید",
        domestic_country = "کشور داخلی",
        current_country = "کشور فعلی",
        ip_ranges_loaded = "IP ها بارگذاری شده",
        vpn_server = "سرور VPN",
        select_server = "انتخاب سرور",
        connect = "اتصال",
        disconnect = "قطع اتصال",
        reconnect = "اتصال مجدد",
        save = "ذخیره",
        cancel = "انصراف",
        apply = "اعمال",
        refresh = "تازه کردن",
        loading = "در حال بارگذاری...",
        error = "خطا",
        success = "موفق",
        connection_failed = "اتصال ناموفق",
        connection_success = "اتصال موفق",
        please_wait = "لطفاً صبر کنید...",
        checking = "در حال بررسی...",
        no_servers = "سروری موجود نیست",
        server_list = "لیست سرورها",
        latency = "تأخیر",
        select_country = "انتخاب کشور",
        update_ip_ranges = "به‌روزرسانی IP ها",
        last_updated = "آخرین به‌روزرسانی",
        never = "هرگز",
        count = "تعداد",
        routes_updated = "مسیرها به‌روز شد",
        routes_count = "مسیر"
    },
    hi = {
        title = "VPN सेटिंग्स",
        vpn = "VPN",
        vpn_settings = "VPN सेटिंग्स",
        vpn_status = "VPN स्थिति",
        enabled = "सक्षम",
        disabled = "अक्षम",
        connecting = "कनेक्ट हो रहा है",
        connected = "कनेक्टेड",
        disconnected = "डिस्कनेक्टेड",
        split_tunnel = "स्प्लिट टनलिंग",
        split_tunnel_desc = "घरेलू ट्रैफिक सीधे, विदेशी VPN से",
        domestic_ip = "घरेलू IP",
        domestic_ip_desc = "घरेलू IP के लिए देश चुनें",
        domestic_country = "घरेलू देश",
        current_country = "वर्तमान देश",
        ip_ranges_loaded = "IP लोडेड",
        vpn_server = "VPN सर्वर",
        select_server = "सर्वर चुनें",
        connect = "कनेक्ट",
        disconnect = "डिस्कनेक्ट",
        reconnect = "पुनः कनेक्ट",
        save = "सहेजें",
        cancel = "रद्द करें",
        apply = "लागू करें",
        refresh = "रिफ्रेश",
        loading = "लोड हो रहा है...",
        error = "त्रुटि",
        success = "सफल",
        connection_failed = "कनेक्शन विफल",
        connection_success = "कनेक्शन सफल",
        please_wait = "कृपया प्रतीक्षा करें...",
        checking = "जाँच रहा है...",
        no_servers = "कोई सर्वर उपलब्ध नहीं",
        server_list = "सर्वर सूची",
        latency = "विलंब",
        select_country = "देश चुनें",
        update_ip_ranges = "IP अपडेट करें",
        last_updated = "अंतिम अपडेट",
        never = "कभी नहीं",
        count = "संख्या",
        routes_updated = "मार्ग अपडेटेड",
        routes_count = "मार्ग"
    },
    tr = {
        title = "VPN Ayarları",
        vpn = "VPN",
        vpn_settings = "VPN Ayarları",
        vpn_status = "VPN Durumu",
        enabled = "Etkin",
        disabled = "Devre Dışı",
        connecting = "Bağlanıyor",
        connected = "Bağlı",
        disconnected = "Bağlı değil",
        split_tunnel = "Bölünmüş Tünel",
        split_tunnel_desc = "Yerel trafik doğrudan, yabancı trafik VPN üzerinden",
        domestic_ip = "Yerel IP",
        domestic_ip_desc = "Yerel IP için ülke seçin",
        domestic_country = "Yerel Ülke",
        current_country = "Mevcut Ülke",
        ip_ranges_loaded = "IP yüklendi",
        vpn_server = "VPN Sunucusu",
        select_server = "Sunucu seçin",
        connect = "Bağlan",
        disconnect = "Bağlantıyı kes",
        reconnect = "Yeniden bağlan",
        save = "Kaydet",
        cancel = "İptal",
        apply = "Uygula",
        refresh = "Yenile",
        loading = "Yükleniyor...",
        error = "Hata",
        success = "Başarılı",
        connection_failed = "Bağlantı başarısız",
        connection_success = "Bağlantı başarılı",
        please_wait = "Lütfen bekleyin...",
        checking = "Kontrol ediliyor...",
        no_servers = "Kullanılabilir sunucu yok",
        server_list = "Sunucu Listesi",
        latency = "Gecikme",
        select_country = "Ülke seçin",
        update_ip_ranges = "IP'leri güncelle",
        last_updated = "Son güncelleme",
        never = "Hiç",
        count = "Sayı",
        routes_updated = "Rotalar güncellendi",
        routes_count = "rota"
    }
}

    local countries = {
        {code = "cn", name = "China", flag = "🇨🇳"},
        {code = "jp", name = "Japan", flag = "🇯🇵"},
        {code = "us", name = "United States", flag = "🇺🇸"},
        {code = "kr", name = "South Korea", flag = "🇰🇷"},
        {code = "hk", name = "Hong Kong", flag = "🇭🇰"},
        {code = "tw", name = "Taiwan", flag = "🇹🇼"},
        {code = "sg", name = "Singapore", flag = "🇸🇬"},
        {code = "my", name = "Malaysia", flag = "🇲🇾"},
        {code = "th", name = "Thailand", flag = "🇹🇭"},
        {code = "vn", name = "Vietnam", flag = "🇻🇳"},
        {code = "id", name = "Indonesia", flag = "🇮🇩"},
        {code = "ph", name = "Philippines", flag = "🇵🇭"},
        {code = "in", name = "India", flag = "🇮🇳"},
        {code = "pk", name = "Pakistan", flag = "🇵🇰"},
        {code = "bd", name = "Bangladesh", flag = "🇧🇩"},
        {code = "ae", name = "UAE", flag = "🇦🇪"},
        {code = "sa", name = "Saudi Arabia", flag = "🇸🇦"},
        {code = "tr", name = "Turkey", flag = "🇹🇷"},
        {code = "ru", name = "Russia", flag = "🇷🇺"},
        {code = "de", name = "Germany", flag = "🇩🇪"},
        {code = "gb", name = "United Kingdom", flag = "🇬🇧"},
        {code = "fr", name = "France", flag = "🇫🇷"},
        {code = "nl", name = "Netherlands", flag = "🇳🇱"},
        {code = "au", name = "Australia", flag = "🇦🇺"},
        {code = "ca", name = "Canada", flag = "🇨🇦"},
        {code = "br", name = "Brazil", flag = "🇧🇷"}
    }

    local i18n_extra = {
        en = {
            detecting = "Detecting location...",
            detected = "Detected",
            your_ip = "Your IP",
            your_country = "Your Country",
            auto_detect = "Auto-detect",
            detected_success = "Location detected: %s (%s)",
            detection_failed = "Failed to detect location",
            real_ip = "Real IP (before VPN)",
            vpn_ip = "VPN IP (after connect)",
            location = "Location"
        },
        ["zh-CN"] = {
            detecting = "正在检测位置...",
            detected = "已检测",
            your_ip = "您的IP",
            your_country = "您的国家",
            auto_detect = "自动检测",
            detected_success = "已检测位置：%s（%s）",
            detection_failed = "检测位置失败",
            real_ip = "真实IP（VPN前）",
            vpn_ip = "VPN IP（连接后）",
            location = "位置"
        },
        ["zh-TW"] = {
            detecting = "正在偵測位置...",
            detected = "已偵測",
            your_ip = "您的IP",
            your_country = "您的國家",
            auto_detect = "自動偵測",
            detected_success = "已偵測位置：%s（%s）",
            detection_failed = "偵測位置失敗",
            real_ip = "真實IP（VPN前）",
            vpn_ip = "VPN IP（連線後）",
            location = "位置"
        }
    }

function get_lang()
    local lang = nixio.fs.readfile("/etc/vipin_lang")
    if not lang or lang == "" then
        lang = "en"
    end
    return lang:gsub("%s+", "")
end

function get_country_name(code)
    for _, c in ipairs(countries) do
        if c.code == code then
            return c.name
        end
    end
    return code
end

function get_country_flag(code)
    for _, c in ipairs(countries) do
        if c.code == code then
            return c.flag
        end
    end
    return ""
end

function index()
    local lang = get_lang and get_lang() or "en"
    local i = i18n[lang] or i18n["en"]
    entry({"admin", "services", "vpn"}, alias("admin", "services", "vpn", "settings"), i.vpn or "VPN", 50)
    entry({"admin", "services", "vpn", "settings"}, template("vpn/settings"), i.vpn_settings or "VPN Settings", 10)
    entry({"admin", "services", "vpn", "api"}, call("api_get_vpn_status"), nil, 20)
    entry({"admin", "services", "vpn", "api_connect"}, call("api_connect"), nil, 21)
    entry({"admin", "services", "vpn", "api_set_split"}, call("api_set_split_tunnel"), nil, 22)
    entry({"admin", "services", "vpn", "api_detect"}, call("api_auto_detect"), nil, 23)
    entry({"admin", "services", "vpn", "api_update_ips"}, call("api_update_ips"), nil, 24)
    entry({"admin", "services", "vpn", "api_login"}, call("api_login"), nil, 25)
    entry({"admin", "services", "vpn", "api_logout"}, call("api_logout"), nil, 26)
    entry({"admin", "services", "vpn", "api_auth_status"}, call("api_auth_status"), nil, 27)
    entry({"admin", "services", "vpn", "api_renewal"}, call("api_get_renewal_url"), nil, 28)
    entry({"admin", "services", "vpn", "api_servers"}, call("api_get_servers"), nil, 29)
    entry({"admin", "services", "vpn", "api_set_server"}, call("api_set_server"), nil, 30)
end

function api_get_vpn_status()
    local http = require("luci.http")
    local json = require("cjson")
    local util = require("luci.util")
    
    local current_country = util.exec("/usr/sbin/vipin-country-ips get-country 2>/dev/null"):gsub("%s+", "")
    local ip_count = util.exec("/usr/sbin/vipin-country-ips count " .. current_country .. " 2>/dev/null"):gsub("%s+", "")
    local vpn_enabled = luci.model.uci:get("vipin", "vpn", "enabled") or "0"
    local split_enabled = luci.model.uci:get("vipin", "vpn", "split_tunnel") or "0"
    local vpn_connected = util.exec("pgrep -x openconnect >/dev/null && echo '1' || echo '0'"):gsub("%s+", "")
    
    local detect_info = util.exec("/usr/sbin/vipin-detect info 2>/dev/null")
    local detected = false
    local detected_ip = ""
    local detected_country = ""
    local detect_time = ""
    
    if detect_info and detect_info ~= "" then
        detected_ip = string.match(detect_info, '"ip":"([^"]*)"') or ""
        detected_country = string.match(detect_info, '"country":"([^"]*)"') or ""
        detect_time = string.match(detect_info, '"detect_time":"([^"]*)"') or ""
        detected = string.match(detect_info, '"detected":true') ~= nil
    end
    
    if detected_country == "" then
        detected_country = current_country
    end
    
    local lang_key = get_lang()
    local extra_i18n = {
        en = {
            detecting = "Detecting location...",
            detected = "Detected",
            your_ip = "Your IP",
            your_country = "Your Country",
            auto_detect = "Auto-detect",
            detected_success = "Location detected",
            detection_failed = "Failed to detect",
            real_ip = "Real IP",
            vpn_ip = "VPN IP",
            location = "Location"
        },
        ["zh-CN"] = {
            detecting = "正在检测位置...",
            detected = "已检测",
            your_ip = "您的IP",
            your_country = "您的国家",
            auto_detect = "自动检测",
            detected_success = "位置已检测",
            detection_failed = "检测失败",
            real_ip = "真实IP",
            vpn_ip = "VPN IP",
            location = "位置"
        },
        ["zh-TW"] = {
            detecting = "正在偵測位置...",
            detected = "已偵測",
            your_ip = "您的IP",
            your_country = "您的國家",
            auto_detect = "自動偵測",
            detected_success = "位置已偵測",
            detection_failed = "偵測失敗",
            real_ip = "真實IP",
            vpn_ip = "VPN IP",
            location = "位置"
        }
    }
    local extra = extra_i18n[lang_key] or extra_i18n["en"]
    
    local status = {
        vpn_enabled = (vpn_enabled == "1"),
        vpn_connected = (vpn_connected == "1"),
        split_tunnel = (split_enabled == "1"),
        current_country = current_country,
        current_country_name = get_country_name(current_country),
        current_country_flag = get_country_flag(current_country),
        ip_count = tonumber(ip_count) or 0,
        countries = countries,
        detected = detected,
        detected_ip = detected_ip,
        detected_country = detected_country,
        detected_country_name = get_country_name(detected_country),
        detected_country_flag = get_country_flag(detected_country),
        detect_time = detect_time,
        translations = i18n[get_lang()] or i18n["en"],
        extra = extra
    }
    
    http.prepare_content("application/json")
    http.write(json.encode(status))
end

function api_connect()
    local http = require("luci.http")
    local json = require("cjson")
    local util = require("luci.util")
    
    local action = luci.http.formvalue("action") or "connect"
    local result = {success = false, message = ""}
    
    if action == "connect" then
        local output = util.exec("/etc/init.d/vipin-vpn start 2>&1")
        result.success = (util.exec("pgrep -x openconnect >/dev/null && echo 1 || echo 0"):gsub("%s+", "") == "1")
    elseif action == "disconnect" then
        util.exec("/etc/init.d/vipin-vpn stop 2>&1")
        result.success = true
    end
    
    http.prepare_content("application/json")
    http.write(json.encode(result))
end

function api_set_split_tunnel()
    local http = require("luci.http")
    local json = require("cjson")
    local util = require("luci.util")
    
    local enabled = luci.http.formvalue("enabled") or "0"
    local result = {success = false}
    
    luci.model.uci:set("vipin", "vpn", "split_tunnel", enabled)
    luci.model.uci:save("vipin")
    luci.model.uci:commit("vipin")
    
    if enabled == "1" then
        util.exec("/usr/sbin/vipin-vpn-routing enable 2>&1")
    else
        util.exec("/usr/sbin/vipin-vpn-routing disable 2>&1")
    end
    
    result.success = true
    
    http.prepare_content("application/json")
    http.write(json.encode(result))
end

function api_auto_detect()
    local http = require("luci.http")
    local json = require("cjson")
    local util = require("luci.util")
    
    local output = util.exec("/usr/sbin/vipin-detect auto 2>&1")
    
    local success = string.match(output, '"success":true') ~= nil
    local detected_ip = string.match(output, '"ip":"([^"]*)"') or ""
    local country_code = string.match(output, '"country_code":"([^"]*)"') or ""
    local country = string.match(output, '"country":"([^"]*)"') or ""
    local ip_count = tonumber(string.match(output, '"ip_count":([0-9]+)')) or 0
    
    local result = {
        success = success,
        detected_ip = detected_ip,
        country_code = country_code,
        country = country,
        country_name = get_country_name(country),
        country_flag = get_country_flag(country),
        ip_count = ip_count,
        message = success and "Detection successful" or "Detection failed"
    }
    
    if success then
        util.exec("/usr/sbin/vipin-vpn-routing reload 2>&1")
    end
    
    http.prepare_content("application/json")
    http.write(json.encode(result))
end

function api_update_ips()
    local http = require("luci.http")
    local json = require("cjson")
    local util = require("luci.util")
    
    local country = util.exec("/usr/sbin/vipin-country-ips get-country 2>/dev/null"):gsub("%s+", "")
    local output = util.exec("/usr/sbin/vipin-country-ips update " .. country .. " 2>&1")
    local ip_count = util.exec("/usr/sbin/vipin-country-ips count " .. country .. " 2>/dev/null"):gsub("%s+", "")
    
    local result = {
        success = true,
        country = country,
        country_name = get_country_name(country),
        country_flag = get_country_flag(country),
        ip_count = tonumber(ip_count) or 0,
        message = output
    }
    
    http.prepare_content("application/json")
    http.write(json.encode(result))
end

function api_login()
    local http = require("luci.http")
    local json = require("cjson")
    local util = require("luci.util")
    
    local username = luci.http.formvalue("username") or ""
    local password = luci.http.formvalue("password") or ""
    
    local result_json = util.exec("/usr/sbin/vipin-auth login '" .. username .. "' '" .. password .. "' 2>/dev/null")
    
    local success = string.match(result_json, '"status": "valid"') ~= nil
    local status = string.match(result_json, '"status": "([^"]+)"') or "error"
    local message = string.match(result_json, '"message": "([^"]+)"') or ""
    local user_type = string.match(result_json, '"type": "([^"]+)"') or ""
    local expiration = string.match(result_json, '"expiration": "([^"]+)"') or ""
    
    local result = {
        success = success,
        status = status,
        message = message,
        username = username,
        type = user_type,
        expiration = expiration
    }
    
    if success then
        -- Enable auto-connect on boot
        luci.model.uci:set("vipin", "vpn", "enabled", "1")
        luci.model.uci:save("vipin")
        luci.model.uci:commit("vipin")
        -- Start VPN and auth monitor
        util.exec("/etc/init.d/vipin-vpn start 2>&1")
        util.exec("/etc/init.d/vipin-auth start 2>&1")
    end
    
    http.prepare_content("application/json")
    http.write(json.encode(result))
end

function api_logout()
    local http = require("luci.http")
    local json = require("cjson")
    local util = require("luci.util")
    
    -- Disable auto-connect
    luci.model.uci:set("vipin", "vpn", "enabled", "0")
    luci.model.uci:save("vipin")
    luci.model.uci:commit("vipin")
    -- Stop services
    util.exec("/etc/init.d/vipin-vpn stop 2>&1")
    util.exec("/etc/init.d/vipin-auth stop 2>&1")
    util.exec("/usr/sbin/vipin-auth logout 2>/dev/null")

    local result = {
        success = true,
        message = "Logged out successfully"
    }
    
    http.prepare_content("application/json")
    http.write(json.encode(result))
end

function api_auth_status()
    local http = require("luci.http")
    local json = require("cjson")
    local util = require("luci.util")
    
    local status_json = util.exec("/usr/sbin/vipin-auth status 2>/dev/null")
    
    local logged_in = string.match(status_json, '"logged_in":true') ~= nil
    local reason = string.match(status_json, '"reason":"([^"]+)"') or ""
    local username = string.match(status_json, '"username":"([^"]+)"') or ""
    local user_type = string.match(status_json, '"type":"([^"]+)"') or ""
    local expiration = string.match(status_json, '"expiration":"([^"]+)"') or ""
    local auth_time = string.match(status_json, '"auth_time":"([^"]+)"') or ""
    
    local result = {
        logged_in = logged_in,
        reason = reason,
        username = username,
        type = user_type,
        expiration = expiration,
        auth_time = auth_time,
        i18n = {
            logged_in = i18n[get_lang()].logged_in or "Logged In",
            logged_out = i18n[get_lang()].logged_out or "Not Logged In",
            expired = i18n[get_lang()].expired or "Expired",
            not_vip = i18n[get_lang()].not_vip or "Not VIP",
            login_required = i18n[get_lang()].login_required or "Login Required"
        }
    }
    
    http.prepare_content("application/json")
    http.write(json.encode(result))
end

function api_get_renewal_url()
    local http = require("luci.http")
    local json = require("cjson")
    local util = require("luci.util")
    
    local result_json = util.exec("/usr/sbin/vipin-auth renewal-url 2>/dev/null")
    
    local success = string.match(result_json, '"success":true') ~= nil
    local error_msg = string.match(result_json, '"error":"([^"]+)"') or ""
    local url = string.match(result_json, '"url":"([^"]+)"') or ""
    local username = string.match(result_json, '"username":"([^"]+)"') or ""
    local token = string.match(result_json, '"token":"([^"]+)"') or ""
    
    local result = {
        success = success,
        error = error_msg,
        url = url,
        username = username,
        token = token
    }
    
    http.prepare_content("application/json")
    http.write(json.encode(result))
end

function api_get_servers()
    local http = require("luci.http")
    local json = require("cjson")
    local util = require("luci.util")
    local io = require("io")
    
    local servers = {}
    
    local countries = {
        {code = "ar", name = "Argentina", flag = "🇦🇷"},
        {code = "au", name = "Australia", flag = "🇦🇺"},
        {code = "at", name = "Austria", flag = "🇦🇹"},
        {code = "br", name = "Brazil", flag = "🇧🇷"},
        {code = "ca", name = "Canada", flag = "🇨🇦"},
        {code = "cn", name = "China", flag = "🇨🇳"},
        {code = "dk", name = "Denmark", flag = "🇩🇰"},
        {code = "fr", name = "France", flag = "🇫🇷"},
        {code = "de", name = "Germany", flag = "🇩🇪"},
        {code = "hk", name = "Hong Kong", flag = "🇭🇰"},
        {code = "in", name = "India", flag = "🇮🇳"},
        {code = "it", name = "Italy", flag = "🇮🇹"},
        {code = "jp", name = "Japan", flag = "🇯🇵"},
        {code = "kr", name = "Korea", flag = "🇰🇷"},
        {code = "nl", name = "Netherland", flag = "🇳🇱"},
        {code = "nz", name = "New Zealand", flag = "🇳🇿"},
        {code = "pt", name = "Portugal", flag = "🇵🇹"},
        {code = "sg", name = "Singapore", flag = "🇸🇬"},
        {code = "es", name = "Spain", flag = "🇪🇸"},
        {code = "ch", name = "Switzerland", flag = "🇨🇭"},
        {code = "tw", name = "Taiwan", flag = "🇹🇼"},
        {code = "th", name = "Thailand", flag = "🇹🇭"},
        {code = "uk", name = "United Kingdom", flag = "🇬🇧"},
        {code = "us", name = "United States", flag = "🇺🇸"}
    }
    
    local base_domain = luci.model.uci:get("vipin", "vpn", "base_domain") or "fanq.in"
    
    for _, c in ipairs(countries) do
        local server_domain = c.code .. "." .. base_domain
        local output = util.exec("wget -q -O- --timeout=3 https://" .. server_domain .. " 2>/dev/null")
        
        table.insert(servers, {
            code = c.code,
            name = c.name,
            flag = c.flag,
            server = server_domain,
            available = (output and output ~= "")
        })
    end
    
    local result = {
        servers = servers,
        base_domain = base_domain
    }
    
    http.prepare_content("application/json")
    http.write(json.encode(result))
end

function api_set_server()
    local http = require("luci.http")
    local json = require("cjson")
    
    local server = luci.http.formvalue("server") or ""
    
    local success = false
    if server and server ~= "" then
        luci.model.uci:set("vipin", "vpn", "server", server)
        luci.model.uci:save("vipin")
        luci.model.uci:commit("vipin")
        success = true
    end
    
    local result = {
        success = success,
        server = server
    }
    
    http.prepare_content("application/json")
    http.write(json.encode(result))
end
