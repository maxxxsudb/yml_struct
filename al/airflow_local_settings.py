Эта ошибка (`KeyError: 'airflow.task_runner'`) означает, что в вашей конкретной версии Airflow этот логгер по умолчанию не объявлен в базовом словаре конфигурации. Структура `DEFAULT_LOGGING_CONFIG` немного меняется от версии к версии (2.5, 2.7, 2.8 и т.д.).

Чтобы сделать код **абсолютно надежным** для любой версии Airflow (чтобы он не падал, если какого-то логгера нет), нужно просто проверять наличие ключа перед добавлением.

Вот самый красивый и безопасный вариант (Python-way). Скопируйте его целиком:

```python
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
```

**Почему этот код лучше:**
1. Он никогда не выдаст `KeyError`. Если в вашей версии нет `airflow.task_runner`, код просто пропустит его и пойдет дальше.
2. Главный логгер (`airflow.task` — именно он пишет логи ваших дагов) гарантированно обновится.
3. Оригинальные обработчики для S3 останутся нетронутыми.

Сохраняйте, перезапускайте поды, и всё должно взлететь без ошибок!
