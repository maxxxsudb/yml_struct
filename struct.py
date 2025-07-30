#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
import os
import json

# --- НАСТРОЙКА ---
# 1. Укажите путь к вашему YAML файлу
# Пример для Linux/macOS: '/home/user/istio_profile.yaml'
# Пример для Windows: 'C:\\Users\\User\\Documents\\istio_profile.yaml'
FILE_PATH = 'profile.yaml'

# 2. Укажите точный ключ, который нужно найти
# Судя по скриншоту, это 'jwksResolverExtraRootCA'
KEY_TO_FIND = 'jwksResolverExtraRootCA'
# -----------------


def get_indent_and_key(line: str):
    """Анализирует строку, возвращает отступ и ключ."""
    stripped_line = line.lstrip()
    if not stripped_line or stripped_line.startswith('#'):
        return None, None
        
    indent = len(line) - len(stripped_line)
    parts = stripped_line.split(':', 1)
    if len(parts) < 2:
        return None, None
        
    key = parts[0].strip()
    return indent, key


def find_path_in_json(data, target_key):
    """Рекурсивно ищет ключ в объекте, полученном из JSON."""
    if isinstance(data, dict):
        if target_key in data:
            return [target_key]
        for key, value in data.items():
            path = find_path_in_json(value, target_key)
            if path:
                return [key] + path
    elif isinstance(data, list):
        for item in data:
            path = find_path_in_json(item, target_key)
            if path:
                return path
    return None


def find_key_path(file_path: str, target_key: str):
    """
    Находит ключ в YAML, в том числе внутри многострочных JSON-блоков.
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

    for i, line in enumerate(lines):
        # Проверяем, не является ли это началом многострочного блока (как у merged-values)
        if line.strip().endswith(('|-', '|')):
            block_indent, block_key = get_indent_and_key(line)
            if block_key is None:
                continue

            # Сборка родительского пути для самого блока
            outer_path = [block_key]
            current_indent = block_indent
            for j in range(i - 1, -1, -1):
                parent_indent, parent_key = get_indent_and_key(lines[j])
                if parent_key is not None and parent_indent < current_indent:
                    outer_path.insert(0, parent_key)
                    current_indent = parent_indent
                    if current_indent == 0:
                        break
            
            # Собираем содержимое блока
            json_string = ""
            # Находим отступ первой строки содержимого
            content_base_indent = -1
            for k in range(i + 1, len(lines)):
                block_line = lines[k]
                line_indent = len(block_line) - len(block_line.lstrip())
                
                if line_indent <= block_indent and block_line.strip():
                    break # Блок закончился
                
                if content_base_indent == -1 and block_line.strip():
                    content_base_indent = line_indent
                
                if content_base_indent != -1:
                    # Убираем только отступ содержимого, сохраняя внутренние отступы JSON
                    json_string += block_line[content_base_indent:]
            
            # Пытаемся разобрать блок как JSON и найти ключ внутри
            try:
                json_data = json.loads(json_string)
                inner_path = find_path_in_json(json_data, target_key)
                if inner_path:
                    full_path = outer_path + inner_path
                    print(":".join(full_path))
                    sys.exit(0)
            except json.JSONDecodeError:
                # Это не JSON-блок, просто пропускаем
                pass
        
        # Старая логика для простых ключей вне блоков
        indent, key = get_indent_and_key(line)
        if key == target_key:
            path = [key]
            current_indent = indent
            for j in range(i - 1, -1, -1):
                parent_indent, parent_key = get_indent_and_key(lines[j])
                if parent_key is not None and parent_indent < current_indent:
                    path.insert(0, parent_key)
                    current_indent = parent_indent
                    if current_indent == 0:
                        break
            print(":".join(path))
            sys.exit(0)

    print(f"Ключ '{target_key}' не найден в файле '{file_path}'.")
    sys.exit(0)


# --- Запуск скрипта ---
if __name__ == "__main__":
    find_key_path(FILE_PATH, KEY_TO_FIND)
