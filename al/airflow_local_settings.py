import copy
from airflow.config_templates.airflow_local_settings import DEFAULT_LOGGING_CONFIG

LOGGING_CONFIG = copy.deepcopy(DEFAULT_LOGGING_CONFIG)

# 1. Создаем ОДИН хендлер для вывода в консоль (этого достаточно)
LOGGING_CONFIG['handlers']['console_stdout'] = {
    'class': 'logging.StreamHandler',
    'formatter': 'airflow',
    'stream': 'ext://sys.stdout',
}

# 2. Добавляем этот хендлер к нужным логгерам, сохраняя оригинальные (S3)
LOGGING_CONFIG["loggers"]["airflow.task"]["handlers"] += ["console_stdout"]
LOGGING_CONFIG["loggers"]["airflow.task_runner"]["handlers"] += ["console_stdout"]
LOGGING_CONFIG["loggers"]["airflow.processor"]["handlers"] += ["console_stdout"]
