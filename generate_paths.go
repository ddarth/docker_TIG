package main

import (
	"fmt"
	"os"
	"strings"
)

// Функция для преобразования "huawei_" в корректное имя типа
func toTypeName(protoFile string) string {
	// Удаляем префикс "huawei_"
	withoutPrefix := strings.TrimPrefix(protoFile, "huawei-")
	//fmt.Println(withoutPrefix)
	// Заменяем дефисы на пробелы
	withoutDashes := strings.ReplaceAll(withoutPrefix, "-", " ")
	// Делаем каждое слово с заглавной буквы
	titleCase := strings.Title(withoutDashes)
	// Убираем пробелы, чтобы получить PascalCase
	return strings.ReplaceAll(titleCase, " ", "")
}

func main() {
	// Получение списка файлов из переменной окружения
	protoFiles := os.Getenv("PROTO_FILES")
	if protoFiles == "" {
		fmt.Println("PROTO_FILES environment variable is not set")
		os.Exit(1)
	}

	// Разбиваем список файлов
	files := strings.Split(protoFiles, " ")

	// Генерация строк
	for _, file := range files {
		// Преобразуем имя файла в формат PascalCase для имени типа
		typeName := toTypeName(file)

		// Преобразуем имя файла (замена дефисов на подчеркивания для пакета)
		packageName := strings.ReplaceAll(file, "-", "_")

		// Формируем строку
		fmt.Printf(`PathKey{ProtoPath: "%s.%s", Version: "1.0"}: []reflect.Type{reflect.TypeOf((*%s.%s)(nil))},`+"\n",
			packageName, typeName, packageName, typeName)
	}
}

