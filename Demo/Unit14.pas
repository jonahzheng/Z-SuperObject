unit Unit14;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Diagnostics,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Memo.Types,
  FMX.StdCtrls, FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo, ZSuperObject;

type
  TForm14 = class(TForm)
    Memo1: TMemo;
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
  private
    procedure Log(const S: String);
    procedure RunBenchmark;
    procedure BenchParse;
    procedure BenchFieldAccess;
    procedure BenchAddPair;
    procedure BenchSerialize;
    procedure BenchStringEscape;
  public
  end;

var
  Form14: TForm14;

implementation

{$R *.fmx}

procedure TForm14.Log(const S: String);
begin
  Memo1.Lines.Add(S);
end;

{ ──────────────────────────────────────────────────────────────────
  Test 1: JSON Parsing
  Parse a 20-field JSON string 5000 times.
  Measures lexer + TJSONObject construction (AddPair for each field).
  ────────────────────────────────────────────────────────────────── }
procedure TForm14.BenchParse;
const
  ITERS = 5000;
  JSON_20 =
    '{"f01":"value01","f02":12345,"f03":true,"f04":1.23,"f05":"value05",' +
    '"f06":"value06","f07":67890,"f08":false,"f09":4.56,"f10":"value10",' +
    '"f11":"value11","f12":11111,"f13":true,"f14":7.89,"f15":"value15",' +
    '"f16":"value16","f17":22222,"f18":false,"f19":0.01,"f20":"value20"}';
var
  SW: TStopwatch;
  I: Integer;
  X: ISuperObject;
  US: Double;
begin
  Log('-- Test 1: JSON Parse (20 fields x ' + ITERS.ToString + ' iters) --');
  SW := TStopwatch.StartNew;
  for I := 1 to ITERS do
    X := SO(JSON_20);
  SW.Stop;
  US := SW.Elapsed.TotalMilliseconds / ITERS * 1000;
  Log(Format('  Total : %d ms', [SW.ElapsedMilliseconds]));
  Log(Format('  Per op: %.2f us', [US]));
  Log('');
end;

{ ──────────────────────────────────────────────────────────────────
  Test 2: Field Access by Name  (O(n) -> O(1) main focus)
  Build objects of various sizes, then repeatedly look up the
  LAST field (worst case for linear scan) to maximise the gap.
  ────────────────────────────────────────────────────────────────── }
procedure TForm14.BenchFieldAccess;
const
  ITERS = 50000;
  SIZES: array[0..4] of Integer = (5, 10, 20, 50, 100);
var
  SW: TStopwatch;
  N, I, K: Integer;
  Obj: ISuperObject;
  V: String;
  LastKey: String;
  US: Double;
begin
  Log('-- Test 2: Field Access - last-field lookup --');
  Log(Format('  %-10s  %-14s  %-12s', ['Fields', 'Total(ms)', 'Per op(us)']));
  for N in SIZES do
  begin
    Obj := SO('{}');
    for K := 1 to N do
      Obj.S[Format('field%d', [K])] := Format('value%d', [K]);
    LastKey := Format('field%d', [N]);

    SW := TStopwatch.StartNew;
    for I := 1 to ITERS do
      V := Obj.S[LastKey];
    SW.Stop;
    US := SW.Elapsed.TotalMilliseconds / ITERS * 1000;
    Log(Format('  %-10d  %-14d  %-12.3f', [N, SW.ElapsedMilliseconds, US]));
  end;
  Log('');
end;

{ ──────────────────────────────────────────────────────────────────
  Test 3: AddPair  (build + duplicate-key update)
  ────────────────────────────────────────────────────────────────── }
procedure TForm14.BenchAddPair;
const
  FIELDS = 100;
  ITERS  = 2000;
var
  SW: TStopwatch;
  I, K: Integer;
  Obj: ISuperObject;
  US: Double;
begin
  Log(Format('-- Test 3: AddPair (%d fields x %d iters) --', [FIELDS, ITERS]));

  SW := TStopwatch.StartNew;
  for I := 1 to ITERS do
  begin
    Obj := SO('{}');
    for K := 1 to FIELDS do
      Obj.S[Format('field%d', [K])] := 'v';
  end;
  SW.Stop;
  US := SW.Elapsed.TotalMilliseconds / ITERS * 1000;
  Log(Format('  Build  total : %d ms  (%.2f us/obj)', [SW.ElapsedMilliseconds, US]));

  Obj := SO('{}');
  for K := 1 to FIELDS do
    Obj.S[Format('field%d', [K])] := 'original';

  SW := TStopwatch.StartNew;
  for I := 1 to ITERS do
    for K := 1 to FIELDS do
      Obj.S[Format('field%d', [K])] := 'updated';
  SW.Stop;
  US := SW.Elapsed.TotalMilliseconds / (ITERS * FIELDS) * 1000;
  Log(Format('  Update total : %d ms  (%.3f us/field)', [SW.ElapsedMilliseconds, US]));
  Log('');
end;

{ ──────────────────────────────────────────────────────────────────
  Test 4: JSON Serialization
  Serialize a 50-field object 10000 times.
  Benefits from AppendKey/AppendQuoted (zero temp-string allocs).
  ────────────────────────────────────────────────────────────────── }
procedure TForm14.BenchSerialize;
const
  FIELDS = 50;
  ITERS  = 10000;
var
  SW: TStopwatch;
  I, K: Integer;
  Obj: ISuperObject;
  S: String;
  US: Double;
begin
  Log(Format('-- Test 4: Serialize (%d fields x %d iters) --', [FIELDS, ITERS]));

  Obj := SO('{}');
  for K := 1 to FIELDS do
    Obj.S[Format('field%d', [K])] := Format('value_string_%d', [K]);

  SW := TStopwatch.StartNew;
  for I := 1 to ITERS do
    S := Obj.AsJSON;
  SW.Stop;
  US := SW.Elapsed.TotalMilliseconds / ITERS * 1000;
  Log(Format('  Total : %d ms', [SW.ElapsedMilliseconds]));
  Log(Format('  Per op: %.2f us', [US]));
  Log('');
end;

{ ──────────────────────────────────────────────────────────────────
  Test 5: String Escape  (O(n^2) -> O(n) fast-path)
  Plain strings: zero-copy fast path.
  Escaped strings: StringBuilder vs + concatenation.
  ────────────────────────────────────────────────────────────────── }
procedure TForm14.BenchStringEscape;
const
  ITERS = 20000;
  PLAIN  = 'The quick brown fox jumps over the lazy dog 0123456789 ABCDEFGHIJ';
  ESCAPE = 'line1'#10'line2'#9'"quoted"'#13'end\done';
var
  SW: TStopwatch;
  I, K: Integer;
  Obj: ISuperObject;
  S: String;
  US: Double;
begin
  Log(Format('-- Test 5: String Escape (x %d iters, 20 fields each) --', [ITERS]));

  Obj := SO('{}');
  for K := 1 to 20 do
    Obj.S[Format('f%d', [K])] := PLAIN;
  SW := TStopwatch.StartNew;
  for I := 1 to ITERS do
    S := Obj.AsJSON;
  SW.Stop;
  US := SW.Elapsed.TotalMilliseconds / ITERS * 1000;
  Log(Format('  Plain  strings total: %d ms  (%.2f us/op)', [SW.ElapsedMilliseconds, US]));

  Obj := SO('{}');
  for K := 1 to 20 do
    Obj.S[Format('f%d', [K])] := ESCAPE;
  SW := TStopwatch.StartNew;
  for I := 1 to ITERS do
    S := Obj.AsJSON;
  SW.Stop;
  US := SW.Elapsed.TotalMilliseconds / ITERS * 1000;
  Log(Format('  Escape strings total: %d ms  (%.2f us/op)', [SW.ElapsedMilliseconds, US]));
  Log('');
end;

procedure TForm14.RunBenchmark;
begin
  Memo1.Lines.BeginUpdate;
  try
    Memo1.Lines.Clear;
    Log('================================================');
    Log('     ZSuperObject Performance Benchmark');
    Log('     ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    Log('================================================');
    Log('');
    BenchParse;
    BenchFieldAccess;
    BenchAddPair;
    BenchSerialize;
    BenchStringEscape;
    Log('== Done ==');
  finally
    Memo1.Lines.EndUpdate;
  end;
end;

{ ── Original demo handlers ── }

procedure TForm14.Button1Click(Sender: TObject);
const
  JSON = '{ "o": { '+
         '    "1234567890": {'+
         '    "last use date": "2010-10-17T01:23:20",'+
         '    "create date": "2010-10-17T01:23:20",'+
         '    "name": "iPhone 8s"'+
         '        }'+
         '  },'+
         '  "Index": 0, '+
         '  "Data": {"Index2": 1}, '+
         '  "a": [{'+
         '    "last use date": "2010-10-17T01:23:20",'+
         '    "create date": "2010-11-17T01:23:20",'+
         '    "name": "iPhone 8s",'+
         '    "arr": [1,2,3] '+
         '  }, '+
         '  {'+
         '    message: "hello"'+
         '  }]'+
         '}';
var
  X: ISuperObject;
  NewJSon: ISuperObject;
  NewArray: ISuperArray;
begin
  X := SO(JSON);
  ShowMessage( X['o."1234567890"."last use date"'].AsString );
  ShowMessage( X['a[Index]."create date"'].AsString );
  ShowMessage( X['a[Data.Index2].message'].AsString );
  X['a[0].arr'].AsArray.Add('test1');
  NewJSON := X['{a: a[Index], b: a[Data.Index2].message, c: o."1234567890".name, d: 4, e: a[0].arr[2], f: " :) "}'].AsObject;
  NewArray := X['[a[Index], a[Data.Index2].message, Data.Index2, Index, 1, "1", "test"]'].AsArray;
end;

procedure TForm14.Button2Click(Sender: TObject);
var
  FilterJSON: ISuperObject;
begin
  FilterJSON := SO('{ Table: [ '+
                   '   { Name: "Sakar SHAKIR", Sex: "M", Size: 1.75 }, '+
                   '   { Name: "Bulent ERSOY", Sex: "F", Size: 1.60 }, '+
                   '   { Name: "Cicek ABBAS",  Sex: "M", Size: 1.65 } '+
                   '  ] }');
  Memo1.Lines.Add(
      FilterJSON.A['Table'].Where(function(Arg: IMember): Boolean
      begin
        with Arg.AsObject do
          Result := (S['Sex'] = 'M') and (F['Size'] > 1.60)
      end).AsJSON
  );
end;

procedure TForm14.Button3Click(Sender: TObject);
var
  FilterJSON: ISuperObject;
begin
  FilterJSON := SO('{ Table: [ '+
                   '   { Name: "Sakar SHAKIR", Sex: "M", Size: 1.75 }, '+
                   '   { Name: "Bulent ERSOY", Sex: "F", Size: 1.60 }, '+
                   '   { Name: "Cicek ABBAS",  Sex: "M", Size: 1.65 } '+
                   '  ] }');
  Memo1.Lines.Add(
      FilterJSON.A['Table'].Delete(function(Arg: IMember): Boolean
      begin
        with Arg.AsObject do
          Result := (S['Sex'] = 'M') and (F['Size'] > 1.60)
      end).AsJSON
  );
end;

procedure TForm14.Button4Click(Sender: TObject);
begin
  RunBenchmark;
end;

end.
