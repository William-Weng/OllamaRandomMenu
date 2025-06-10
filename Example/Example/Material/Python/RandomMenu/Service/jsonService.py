import json

def writeVectorJSON(list: list, filename: str, encoding: str):
    """
    將問題List向量 => 存成.json

    參數:
        list: 資料列表
        filename: 檔案名稱
        encoding: 文字編碼
    """
    with open(filename, 'w', encoding=encoding) as file:
        json.dump(list, file, ensure_ascii=False)