import requests, pandas, os, time, random, json, numpy, datetime
import RandomMenu.configure as config
from scipy.spatial.distance import cosine

def embeddings(text: str):
    """
    將文字 => 向量

    參數:
        text: 要換成向量的文字
    """
    json = { 'model': config.Model, 'input': [text] }

    response = requests.post(f'{config.OllamaAPI}/api/embed', json=json)
    return response.json()['embeddings'][0]

def vectorList(dataFrame: pandas.DataFrame):
    """
    將CSV問題 => 向量

    參數:
        dataFrame: 已讀出的CSV檔資訊
    """
    list = []

    for row in dataFrame.itertuples():
        key = row.gpt_q
        value = embeddings(key)
        list.append({'question': key, 'vector': value})

    return list

def fileExists(file: str):
    """
    測試檔案是否存在

    參數:
        file: 檔案路徑名稱
    """
    return os.path.exists(file)

def readVectorJSON(filename: str, encoding: str):
    """
    將向量json => Array

    參數:
        filename: 檔案名稱
        encoding: 文字編碼
    """
    with open(filename, 'r', encoding=encoding) as file:
        list = json.load(file)

    return numpy.asarray(list)

def parseSimilarMap(similarity: float, threshold: float, index: int):
    """
    過濾取得在相似度以內的資訊

    參數:
        similarity: 相似度
        threshold: 相似度基礎值
        index: 第幾筆
    """
    if (similarity < threshold): return None

    map = {}
    map["similarity"] = similarity
    map["index"] = index

    return map

def similarList(dataFrame: pandas.DataFrame, indexArray: list):
    """
    從已讀出的CSV檔資訊 => 取出特定index的資訊

    參數:
        dataFrame: 已讀出的CSV檔資訊
        indexArray: 特定index列表
    """

    indices = []
    for index in range(len(indexArray)):
        indices.append(indexArray[index]["index"])
    
    return dataFrame.iloc[indices]

def similarIndexList(input: str, vectorArray: list, threshold: float):
    """
    將輸入文字比較相似值

    參數:
        input: 輸入文字
        vectorArray: 轉成向量的比較列表
        threshold: 相似值的基準值 (0.0 ~ 1.0)
    """
    indexArray = []
    inputVector = embeddings(input)

    for index in range(len(vectorArray)):

        vector = vectorArray[index]["vector"]
        similarity = 1 - cosine(inputVector, vector)
        similarMap = parseSimilarMap(similarity=similarity, threshold=threshold, index=index)

        if similarMap is not None: indexArray.append(similarMap)

    return indexArray

def combineQuestions(rows: pandas.DataFrame, indexArray: list):
    """
    從已讀出的CSV檔資訊 => 方便前台處理的格式

    參數:
        rows: 已讀出的特定列的CSV檔資訊
        indexArray: 特定index列表
    """
    questions = []

    for index in range(len(rows)):

        similarity = 1.0
        row = rows.iloc[index] 
        _index_ = int(row._index_)
        gpt_q = f'根據{row.files}內容，分析{row.gpt_q}'
        user_q = row.user_q
        
        if (indexArray != None): similarity = float(indexArray[index]["similarity"])
        questions.append({ "_index_": _index_, "gpt_q":gpt_q, "user_q": user_q, "similarity": similarity })

    return questions

def randomMenu(dataFrame: pandas.DataFrame, count: int):
    """
    從已讀出的CSV檔資訊 => 隨機取得3筆選單

    參數:
        count: 隨機幾筆選單
    """
    n = count
    maxCount = len(dataFrame)
    randomState = int(time.time())
    
    if count > maxCount: n = maxCount
    return dataFrame.sample(n=n, replace=False, random_state = randomState)

def combineRandomMenu(dataFrame: pandas.DataFrame, count: int):
    """
    從已讀出的CSV檔資訊 => 方便前台處理格式的隨機選單

    參數:
        rows: 已讀出的特定列的CSV檔資訊
        indexArray: 特定index列表
    """
    menu = randomMenu(dataFrame, count)
    return combineQuestions(menu, None)

def randomQuestions(questions: list, count: int, dataFrame: pandas.DataFrame):
    """
    隨機選單問題 => {"result:":{"menu":[<CSV中的選單問題>],"question":[<比較後產生的近似問題>]},"error":<錯誤訊息>}

    參數:
        questions: 已經過濾相似度的問題
        count: 隨機幾筆選單
        dataFrame: CSV選單的資料
    """
    code = 200
    randomMenu = None
    randomQuestions = None

    random.shuffle(questions)
    randomQuestions = questions[:count]
    randomQuestions.sort(key=lambda q : q["similarity"])

    if not randomQuestions:
        code = 422
        error = {}
        error["message"] = "抱歉，我不太了解您的問題，這裡提供了幾個相似的，您所指的是這些嗎？👉"
        randomMenu = combineRandomMenu(dataFrame, count)
        randomQuestions = None
        return { "result": { "menu": randomMenu, "question": None }, "error": error }, code

    return { "result": { "menu": None, "question": randomQuestions }, "error": None }, code

def searchMenu(table = config.CSVPath, indices: list = None):
    """
    搜尋特定位置的選單 => {"result:":{"menu":[<CSV中的選單問題>],"question":nil},"error":nil}

    參數:
        table: CSV檔案路徑
        indices: 特定index列表
    """
    dataFrame = pandas.read_csv(table)
    rows = dataFrame.iloc[indices]

    menus = []

    for index in range(len(rows)):

        similarity = 1.0
        row = rows.iloc[index] 
        _index_ = int(row._index_)
        gpt_q = f'根據{row.files}內容，分析{row.gpt_q}'
        user_q = row.user_q

        menus.append({ "_index_": _index_, "gpt_q":gpt_q, "user_q": user_q, "similarity": similarity })

    return { "result": { "menu": menus }, "error": None }, 200

def dateTimestamp(date: str, format: str = "%Y-%m-%d %H:%M:%S.%f"):
    """
    時間字串轉換時間戳 (2025-05-07 13:37:43.675000 => 1683439063.675000)
    """
    dt = datetime.datetime.strptime(date, format)
    timestamp = time.mktime(dt.timetuple()) + dt.microsecond / 1e6

    return timestamp * 1000
