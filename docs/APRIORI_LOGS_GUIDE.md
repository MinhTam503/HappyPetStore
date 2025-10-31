# Hướng dẫn đọc log Apriori (HappyPetStore)

Tài liệu này giải thích cấu trúc log Apriori do ứng dụng ghi ra, theo từng pha “đúng sách giáo khoa”, giúp bạn kiểm tra thuật toán: join → prune → count → sinh luật, và đường rẽ fallback khi không có luật.

- File log: `apriori_logs.json` (thư mục documents của ứng dụng)
- App sẽ in đường dẫn tuyệt đối ở lần ghi đầu: `📄 Apriori logs file path: /.../apriori_logs.json`
- Bạn cũng có thể gọi `AprioriLogger.getLogFilePath()` để lấy đường dẫn.

## Ký hiệu nhanh
- N: số giao dịch (transactions)
- sup(X): support count của tập X (số giao dịch chứa X)
- s(X) = sup(X) / N: tần suất
- conf(A→B) = sup(A∪B) / sup(A)
- lift(A→B) = conf / s(B)

## Vòng đời một lần chạy
1) RUN_START: mở đầu một run với tham số
2) FETCH_* / MAP_* / TRANSACTIONS_*: tải đơn hàng, map product → breed, dựng transactions
3) INIT / DATA: cấu hình ngưỡng và thống kê dữ liệu
4) K-level logs (K1_CANDIDATES, K1_COUNT, K_JOIN, K_PRUNE, K_COUNT, L_LEVEL)
5) RULE_EVAL: đánh giá từng luật A→B (khi có Lk, k≥2)
6) SUMMARY / MINING_SUMMARY: tổng kết mining
7) RANKING_SCORES / SUGGESTED_BREEDS: xếp hạng theo luật
8) Fallback (PAIR_COUNT_DETAILS / FALLBACK_PAIRS / POPULAR_FALLBACK): khi không có luật
9) PET_RESULTS: kết quả thú cưng (kèm id, name, breed)
10) RUN_COMPLETE: kết thúc run với số liệu thời gian

---

## 1) Cấu hình & dữ liệu đầu vào
- INIT
  - `minSupport`, `minSupportCount`, `minConfidence`
- DATA
  - `transactions` (N) và `avgLen` (độ dài trung bình của một giao dịch)

Ví dụ:
```json
{"type":"INIT","minSupport":0.01,"minSupportCount":1,"minConfidence":0.1}
{"type":"DATA","transactions":73,"avgLen":2.26}
```

## 2) K=1 (C1 → L1)
- K1_CANDIDATES
  - Tất cả item đơn xuất hiện trong dữ liệu
- K1_COUNT
  - Support từng item kèm `TIDs` (ví dụ T1..Tn là chỉ số giao dịch, giúp debug giao cắt)

Ví dụ:
```json
{"type":"K1_CANDIDATES","items":["Bacgie","Chihuahua","Chim sáo",...]}
{"type":"K1_COUNT","entries":[{"item":"Phốc sóc","support":49,"tids":["T1","T2",...]}]}
```
L1 chính là các item có `support ≥ minSupportCount`.

## 3) K≥2 (Join + Prune + Count → Lk)
- K_JOIN
  - Liệt kê các phép join L(k-1) ⋈ L(k-1) để tạo Ck: `{a} ⋈ {b} -> {a,b}`
- K_PRUNE
  - Loại candidate nếu tồn tại bất kỳ (k-1)-subset không thuộc L(k-1)
  - Log trường `missingSubsets` để giải thích lý do bị loại
- K_COUNT
  - Đếm support cho các candidate còn lại (có thể kèm `tids`)
- L_LEVEL
  - Kết quả Lk với các itemset `support ≥ minSupportCount`

Ví dụ (lý tưởng ở K=2):
```json
{"type":"K_JOIN","k":2,"joins":[{"a":["bread"],"b":["milk"],"c":["bread","milk"]}]}
{"type":"K_PRUNE","k":2,"pruned":[]}
{"type":"K_COUNT","k":2,"entries":[{"itemset":["bread","milk"],"support":4,"tids":["T1","T2","T6","T7"]}]}
{"type":"L_LEVEL","k":2,"size":1,"itemsets":[{"itemset":["bread","milk"],"support":4}]}
```

Lưu ý kỹ: “prune đúng” nghĩa là chỉ loại khi một subset kích thước k-1 không có trong L(k-1). Nếu L1 chứa mọi item đơn, thì ở K=2 gần như không có prune.

## 4) Sinh luật (khi có Lk, k≥2)
- RULE_EVAL (được ghi cho mỗi A→B)
  - `supportF` = sup(A∪B), `supportA` = sup(A), `supportB` = sup(B)
  - `confidence`, `lift`, `passMinConfidence`

Ví dụ:
```json
{"type":"RULE_EVAL","A":["bread"],"B":["milk"],"supportF":4,"supportA":5,"supportB":6,"confidence":0.8,"lift":1.0667,"passMinConfidence":true}
```

## 5) Tổng kết mining
- SUMMARY
  - `iterations` (số mức k chạy), `totalCandidates`, `totalPruned`, `frequentItemsets`, `frequentByLevel`, `rulesKept`, `rulesEvaluated`
- MINING_SUMMARY
  - Thêm `topL1`, `rulesByAntecedentSize`, `candidateStats`

## 6) Xếp hạng & Fallback
- RANKING_SCORES
  - Điểm theo luật cho các giống gợi ý
- SUGGESTED_BREEDS
  - Danh sách giống theo luật
- PAIR_COUNT_DETAILS (fallback: đếm cặp)
  - `uniquePairCount`: số cặp khác nhau
  - `topPairsGlobal`: bảng xếp hạng cặp theo `count`
  - `selectedDetails`: cho từng giống đã chọn – `support` và `topCombined {with,count,confidence}`
- FALLBACK_PAIRS
  - Kết quả giống gợi ý từ cặp
- POPULAR_FALLBACK
  - Nếu không có cặp phù hợp, gợi ý theo L1 phổ biến

## 7) Kết quả thú cưng
- PET_RESULTS
  - `requestedBreeds`: những breed yêu cầu query
  - `resultCount`
  - `pets`: danh sách thú cưng kèm `id`, `name`, `breed`

Ví dụ:
```json
{
  "type":"PET_RESULTS",
  "requestedBreeds":["Chim yến phụng"],
  "resultCount":2,
  "pets":[
    {"id":"254023129","name":"Chim Bay Mau","breed":"Chim yến phụng"},
    {"id":"704787143","name":"Chim hút mật","breed":"Chim yến phụng"}
  ]
}
```

## 8) Ví dụ diễn giải (case “Chim sáo”)
- L1:
  - Phốc sóc(49), Golden Retriever(44), Chihuahua(35), Bacgie(32), Chim yến phụng(2), Chim sáo(2), Husky(1)
- K=2:
  - Trong log ví dụ, toàn bộ 21 cặp bị `K_PRUNE` do “missingSubsets” dù L1 có đủ – đây là dấu hiệu bug kiểm tra subset (xem mục Troubleshooting). Do đó không sinh luật.
- Fallback cặp:
  - `PAIR_COUNT_DETAILS` cho thấy cặp mạnh với “Chim sáo” là “Chim yến phụng” (count=2, confidence=1.0)
  - `FALLBACK_PAIRS` → gợi ý “Chim yến phụng”
- PET_RESULTS:
  - Trả về 2 thú cưng, có đầy đủ `id`, `name`, `breed`

## 9) Troubleshooting (phát hiện qua log)
1) Toàn bộ cặp ở K=2 bị prune sai:
   - Dấu hiệu: `K_JOIN.joins=[]` hoặc `K_PRUNE` có tất cả cặp với `missingSubsets` là các item đơn vốn có trong L1.
   - Nguyên nhân phổ biến: dùng `Map<Set<String>, int>` cho frequent itemsets. So sánh key kiểu Set trong Dart là theo danh tính, không theo nội dung → `containsKey(subset)` thất bại vì subset là Set mới tạo.
   - Cách khắc phục: chuẩn hoá key itemset thành chuỗi sắp xếp, ví dụ: `key = items.sort().join('::')`. Sử dụng `Map<String,int>` thay cho `Map<Set<String>,int>`, có helper `canonicalKey(Set)` và dùng key đó mọi nơi join/prune/lookup.

2) Không có luật vì dữ liệu thưa:
   - Giảm `minConfidence`, hoặc tăng `maxItemsetSize`, hoặc tích luỹ thêm transactions.
   - Kiểm tra `MINING_SUMMARY.topL1` và `candidateStats` để hiểu mức độ thưa.

3) Kiểm tra đếm support sai:
   - So sánh `K_COUNT.entries[].tids` với `K1_COUNT` của từng phần tử để bắt lỗi giao cắt.

4) Hiệu năng & độ ồn log:
   - Log chi tiết (RULE_EVAL/K_COUNT với TIDs) chủ yếu để debug; có thể tắt khi lên production.

## 10) Phụ lục: các loại log chính
- RUN_START, RUN_COMPLETE
- FETCH_ORDERS_START/END, PRODUCT_IDS_COLLECTED, FETCH_PETS_START/CHUNK, MAP_BREEDS_SUMMARY
- TRANSACTIONS_BUILT, TRANSACTIONS_INFO
- INIT, DATA
- K1_CANDIDATES, K1_COUNT
- K_JOIN, K_PRUNE, K_COUNT, L_LEVEL
- RULE_EVAL, SUMMARY, MINING_SUMMARY
- RANKING_SCORES, SUGGESTED_BREEDS
- PAIR_COUNT_DETAILS, FALLBACK_PAIRS, POPULAR_FALLBACK
- PET_RESULTS, NO_DATA

---

Nếu bạn muốn, có thể bật thêm thống kê khác như conviction/leverage cho RULE_EVAL, hoặc luôn ghi PAIR_COUNT_DETAILS kể cả khi có luật, để so sánh hai hướng xếp hạng.
