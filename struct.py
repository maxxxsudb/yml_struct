#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
import os

# --- НАСТРОЙКА ---
# 1. Укажите путь к вашему YAML файлу
FILE_PATH = 'test.yml'

# 2. Укажите ключ, который нужно найти
KEY_TO_FIND = 'target_key'
# -----------------


def get_indent_and_key(line: str):
    """Анализирует строку, возвращает отступ и ключ."""
    stripped_line = line.lstrip()
    if not stripped_line or stripped_line.startswith('#') or stripped_line.startswith('- '):
        return None, None
        
    indent = len(line) - len(stripped_line)
    parts = stripped_line.split(':', 1)
    if len(parts) < 2:
        return None, None
        
    key = parts[0].strip()
    if key.startswith('- '):
        key = key[2:].strip()

    return indent, key


def find_first_path(file_path: str, target_key: str):
    """
    Находит первое вхождение ключа, выводит его путь и завершает работу.
    """
    if not os.path.exists(file_path):
        print(f"Ошибка: Файл не найден по пути '{file_path}'")
        sys.exit(1)

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception as e:
        print(f"Ошибка при чтении файла: {e}")
        sys.exit(1)

    # Проходим по каждой строке файла
    for i, line in enumerate(lines):
        indent, key = get_indent_and_key(line)

        # Если нашли нужный ключ
        if key == target_key:
            path = [key]
            current_indent = indent
            
            # Ищем родителей, двигаясь вверх по файлу
            for j in range(i - 1, -1, -1):
                parent_line = lines[j]
                parent_indent, parent_key = get_indent_and_key(parent_line)

                # Родитель - это строка с меньшим отступом
                if parent_key is not None and parent_indent < current_indent:
                    path.insert(0, parent_key)
                    current_indent = parent_indent
                    if current_indent == 0:
                        break
            
            # Выводим результат и немедленно выходим
            print(":".join(path))
            sys.exit(0) 

    # Если цикл завершился, а ключ не был найден
    print(f"Ключ '{target_key}' не найден в файле '{file_path}'.")
    sys.exit(0)


# --- Запуск скрипта ---
if __name__ == "__main__":
    find_first_path(FILE_PATH, KEY_TO_FIND)