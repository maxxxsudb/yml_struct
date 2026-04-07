
import copy
from airflow.config_templates.airflow_local_settings import DEFAULT_LOGGING_CONFIG

LOGGING_CONFIG = copy.deepcopy(DEFAULT_LOGGING_CONFIG)

# 1. Создаем ОДИН хендлер для вывода в консоль
LOGGING_CONFIG['handlers']['console_stdout'] = {
    'class': 'logging.StreamHandler',
    'formatter': 'airflow',
    'stream': 'ext://sys.stdout',
}

# 2. Список логгеров, куда мы хотим добавить вывод в консоль
loggers_to_update = [
    "airflow.task", 
    "airflow.processor", 
    "airflow.task_runner"
]

# 3. Безопасно добавляем наш хендлер ТОЛЬКО если логгер существует
for logger_name in loggers_to_update:
    if logger_name in LOGGING_CONFIG["loggers"]:
        LOGGING_CONFIG["loggers"][logger_name]["handlers"].append("console_stdout")

3. Оригинальные обработчики для S3 останутся нетронутыми.

Сохраняйте, перезапускайте поды, и всё должно взлететь без ошибок!
