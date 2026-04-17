<h1 align="center">Z-SuperObject</h1>

<h3 align="center">Delphi cross-platform high-performance JSON library — O(1) field lookup, 18× faster serialization.</h3>

<p align="center">
  <img src="https://img.shields.io/badge/Delphi-XE2%2B-blue.svg" alt="Delphi">
  <img src="https://img.shields.io/badge/Platform-Win32%20Win64%20macOS%20iOS%20Android-green.svg" alt="Platform">
  <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License">
  <img src="https://img.shields.io/badge/Pascal-Free%20Pascal%20Compatible-orange.svg" alt="FPC">
</p>

<p align="center">
  <a href="README.zh.md">中文</a> | <strong>English</strong>
</p>

---

> **Z-SuperObject** is a performance-optimized fork of [x-superobject](https://github.com/onryldz/x-superobject), adding O(1) hash-index field lookup, zero-copy serialization, and a clean zero-warning build.

---

## Improvements over x-superobject

### 1. O(1) Field Lookup — `TJSONObject` Hash Index

The original library scans `TList<IJSONPair>` linearly on every `Get`, `AddPair`, and `Remove` call. Z-SuperObject adds a `TDictionary<String, IJSONPair>` hash index, making all key operations O(1) while preserving insertion order.

| Fields | x-superobject | Z-SuperObject | Speedup |
|:------:|:-------------:|:-------------:|:-------:|
| 10 | 2.644 µs | 0.909 µs | **2.9×** |
| 20 | 4.539 µs | 0.987 µs | **4.6×** |
| 50 | 9.964 µs | 0.985 µs | **10×** |
| 100 | 18.496 µs | 1.011 µs | **18×** |

### 2. O(1) `AddPair` with Duplicate-Key Detection

Original `AddPair` called `Get` (O(n)) then `FPairList.Remove` (another O(n)) for every key. Z-SuperObject resolves both in O(1) via hash index.

| Operation | x-superobject | Z-SuperObject | Speedup |
|:----------|:-------------:|:-------------:|:-------:|
| Build 100-field object | 993 µs | 133 µs | **7.5×** |
| Update 100 duplicate keys | 6.879 µs/field | 0.909 µs/field | **7.6×** |

### 3. Zero-Copy String Serialization

Original `StrToUTF16` uses `Result := Result + char` — O(n²) allocations. Z-SuperObject first scans for escaping needs (O(n)), then returns the original string directly (zero copy) or uses `TStringBuilder` (O(n)).

| String type | x-superobject | Z-SuperObject | Speedup |
|:------------|:-------------:|:-------------:|:-------:|
| Plain | 43.75 µs | 8.59 µs | **5.1×** |
| Escaped | 23.59 µs | 11.23 µs | **2.1×** |

### 4. Zero-Allocation JSON Serialization

`TJSONWriter.AppendKey` / `AppendQuoted` write directly to the internal `TStringBuilder` buffer — replacing `'"' + StrToUTF16(name) + '":"'` (2–3 heap allocs/field) with 3 `Append` calls (0 allocs).

| Scenario | x-superobject | Z-SuperObject | Speedup |
|:---------|:-------------:|:-------------:|:-------:|
| Serialize 50-field object | 50.22 µs | 13.94 µs | **3.6×** |

### 5. `TLexBuff` Buffer-Growth Bug Fix

Original condition `Length >= Capacity - Length` triggered at ~67% buffer capacity — allowing writes past the allocated boundary before reallocation (heap corruption risk). Fixed to `Length >= Capacity - 1`.

### 6. Compiler Warnings Eliminated

| | x-superobject | Z-SuperObject |
|:---|:---:|:---:|
| W1029 Duplicate constructor | ⚠️ 2× | ✅ Fixed |
| W1035 Undefined return value | ⚠️ 2× | ✅ Fixed |
| W1036 Uninitialized variable | ⚠️ 1× | ✅ Fixed |
| H2164 Unused variables | 💡 4× | ✅ Fixed |

See **[PERFORMANCE.md](PERFORMANCE.md)** for full benchmark data.

---

## Quick Start

Add `XSuperJSON.pas` and `XSuperObject.pas` to your project.

```pascal
uses XSuperObject;

var X: ISuperObject;
begin
  // Build
  X := SO;
  X.S['name'] := 'Delphi';
  X.I['year'] := 2024;
  X.B['active'] := True;

  // Parse
  X := SO('{"name":"Delphi","year":2024}');
  ShowMessage(X.S['name']);   // 'Delphi'

  // Serialize
  ShowMessage(X.AsJSON);
end;
```

---

## Basic Usage

### Build a JSON Object

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

### Parse & Query

```pascal
const JSON = '{"o":{"id":{"name":"iPhone","date":"2010-10-17T01:23:20"}},' +
             '"Index":0,"a":[{"name":"A","arr":[1,2,3]},{"msg":"hello"}]}';
var X: ISuperObject;
begin
  X := SO(JSON);
  ShowMessage( X['o.id.name'].AsString );          // 'iPhone'
  ShowMessage( X['a[Index].name'].AsString );     // 'A'
  ShowMessage( X['a[1].msg'].AsString );           // 'hello'
end;
```

### Filter

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

### Sort

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

### Marshalling

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

## Compatibility

- **Delphi XE2** and later
- **Windows** (Win32 / Win64), **macOS**, **iOS**, **Android**
- FireMonkey (FMX) and VCL

---

## License

MIT License — same as the original x-superobject.
