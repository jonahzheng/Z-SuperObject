<h1 align="center">Z-SuperObject</h1>

<h3 align="center">Delphi 跨平台高性能 JSON 库 · O(1) 字段查找 · 序列化最高快 18 倍。</h3>

<p align="center">
  <img src="https://img.shields.io/badge/Delphi-XE2%2B-blue.svg" alt="Delphi">
  <img src="https://img.shields.io/badge/Platform-Win32%20Win64%20macOS%20iOS%20Android-green.svg" alt="Platform">
  <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License">
  <img src="https://img.shields.io/badge/Pascal-Free%20Pascal%20Compatible-orange.svg" alt="FPC">
</p>

<p align="center">
  <a href="readme.md">English</a> | <strong>中文</strong>
</p>

---

> **Z-SuperObject** 是 [x-superobject](https://github.com/onryldz/x-superobject) 的性能优化分支，新增 O(1) 哈希索引字段查找、零拷贝序列化、零编译警告。

---

## 相比原版 x-superobject 的改进

### 1. O(1) 字段查找 — `TJSONObject` 哈希索引

原版使用 `TList<IJSONPair>` 线性扫描，每次 `Get`、`AddPair`、`Remove` 都随字段数增长而变慢。Z-SuperObject 在列表旁增加 `TDictionary<String, IJSONPair>` 哈希索引，所有 key 操作降为 O(1)，同时保留插入顺序。

| 字段数 | x-superobject | Z-SuperObject | 提升 |
|:------:|:-------------:|:-------------:|:----:|
| 10 | 2.644 µs | 0.909 µs | **2.9×** |
| 20 | 4.539 µs | 0.987 µs | **4.6×** |
| 50 | 9.964 µs | 0.985 µs | **10×** |
| 100 | 18.496 µs | 1.011 µs | **18×** |

### 2. O(1) `AddPair` 去重检测

原版 `AddPair` 每次调 `Get`（O(n)）再调 `FPairList.Remove`（又一次 O(n)）。Z-SuperObject 通过哈希索引将两次操作都降为 O(1)。

| 操作 | x-superobject | Z-SuperObject | 提升 |
|:-----|:-------------:|:-------------:|:----:|
| 构建100字段对象 | 993 µs | 133 µs | **7.5×** |
| 更新100个重复键 | 6.879 µs/字段 | 0.909 µs/字段 | **7.6×** |

### 3. 零拷贝字符串序列化

原版 `StrToUTF16` 用 `Result := Result + char` 逐字符拼接 — O(n²) 内存分配。Z-SuperObject 先扫描是否需要转义（O(n)），无需转义直接返回原串（零分配零拷贝），需要时用 `TStringBuilder`（O(n)）。

| 字符串类型 | x-superobject | Z-SuperObject | 提升 |
|:-----------|:-------------:|:-------------:|:----:|
| 普通字符串 | 43.75 µs | 8.59 µs | **5.1×** |
| 含特殊字符 | 23.59 µs | 11.23 µs | **2.1×** |

### 4. 零临时分配序列化

`TJSONWriter.AppendKey` / `AppendQuoted` 直接写入 `TStringBuilder` 缓冲区，替换 `'"' + StrToUTF16(name) + '":"'` 的写法（每字段 2~3 次堆分配）为 3 次 `Append` 调用（零分配）。

| 场景 | x-superobject | Z-SuperObject | 提升 |
|:-----|:-------------:|:-------------:|:----:|
| 序列化50字段对象 | 50.22 µs | 13.94 µs | **3.6×** |

### 5. `TLexBuff` 缓冲区增长条件修复

原版条件 `Length >= Capacity - Length` 仅在缓冲区约 67% 满时触发扩容，存在潜在堆损坏风险。修正为 `Length >= Capacity - 1`。

### 6. 消除编译警告

| | x-superobject | Z-SuperObject |
|:---|:---:|:---:|
| W1029 重复构造函数 | ⚠️ 2× | ✅ 已修复 |
| W1035 返回值可能未定义 | ⚠️ 2× | ✅ 已修复 |
| W1036 变量可能未初始化 | ⚠️ 1× | ✅ 已修复 |
| H2164 未使用变量 | 💡 4× | ✅ 已修复 |

完整基准测试数据见 **[PERFORMANCE.md](PERFORMANCE.md)**。

---

## 快速开始

将 `XSuperJSON.pas` 与 `XSuperObject.pas` 加入项目。

```pascal
uses XSuperObject;

var X: ISuperObject;
begin
  // 构建
  X := SO;
  X.S['name'] := 'Delphi';
  X.I['year'] := 2024;
  X.B['active'] := True;

  // 解析
  X := SO('{"name":"Delphi","year":2024}');
  ShowMessage(X.S['name']);   // 'Delphi'

  // 序列化
  ShowMessage(X.AsJSON);
end;
```

---

## 基本用法

### 构建 JSON 对象

```pascal
var X: ISuperObject;
begin
  X := SO;
  X.S['name']  := 'Onur YILDIZ';
  X.B['vip']   := True;
  X.I['age']   := 24;
  X.F['size']  := 1.72;
  with X.A['telephones'] do
  begin
    Add('000000000');
    Add('111111111');
  end;
  ShowMessage(X.AsJSON);
end;
```

### 解析与查询

```pascal
const JSON = '{"o":{"id":{"name":"iPhone","date":"2010-10-17T01:23:20"}},' +
             '"Index":0,"a":[{"name":"A","arr":[1,2,3]},{"msg":"hello"}]}';
var X: ISuperObject;
begin
  X := SO(JSON);
  ShowMessage( X['o.id.name'].AsString );       // 'iPhone'
  ShowMessage( X['a[Index].name'].AsString );   // 'A'
  ShowMessage( X['a[1].msg'].AsString );        // 'hello'
end;
```

### 过滤

```pascal
var F: ISuperObject;
begin
  F := SO('{"Table":[{"Name":"Alice","Sex":"F","Score":90},' +
                     '{"Name":"Bob","Sex":"M","Score":85},' +
                     '{"Name":"Carl","Sex":"M","Score":92}]}');

  ShowMessage(
    F.A['Table'].Where(function(M: IMember): Boolean
    begin
      Result := (M.AsObject.S['Sex'] = 'M') and (M.AsObject.I['Score'] > 88);
    end).AsJSON
  );
  // [{"Name":"Carl","Sex":"M","Score":92}]
end;
```

### 排序

```pascal
var A: ISuperArray;
begin
  A := SA('[{"i":3},{"i":1},{"i":4},{"i":2}]');
  A.Sort(function(L, R: IMember): Integer begin
    Result := CompareValue(L.AsObject.I['i'], R.AsObject.I['i']);
  end);
  ShowMessage(A.AsJSON);  // [{"i":1},{"i":2},{"i":3},{"i":4}]
end;
```

### 序列化映射（Marshalling）

```pascal
type
  TAddress = record
    Street: String;
    City:   String;
  end;
  TPerson = class
    Name:    String;
    Age:     Integer;
    Address: TAddress;
  end;

var P: TPerson;
begin
  P := TPerson.FromJSON('{"Name":"Alice","Age":30,"Address":{"Street":"Main St","City":"NY"}}');
  ShowMessage(P.AsJSON);
end;
```

---

## 兼容性

- **Delphi XE2** 及以上版本
- **Windows**（Win32 / Win64）、**macOS**、**iOS**、**Android**
- FireMonkey (FMX) 和 VCL

---

## 许可证

MIT 许可证，与原始 x-superobject 相同。
