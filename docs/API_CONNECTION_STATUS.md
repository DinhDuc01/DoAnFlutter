# Trạng thái kết nối API

App dùng backend được cấu hình bởi `ApiConfig.baseUrl`. Giá trị mặc định hiện tại là `https://backend-do-an-api-new.onrender.com`.

Luồng request, token, môi trường local và payload được mô tả chi tiết tại [API_INTEGRATION_FLOW.md](API_INTEGRATION_FLOW.md).

## Màn hình đã kết nối

| Chức năng | Backend endpoint |
| --- | --- |
| Đăng nhập | `POST /api/v1/auth/login` |
| Lịch thu mua | `GET /api/v1/paddy-purchase-schedules` |
| Chi tiết lịch thu mua | Dữ liệu lịch và `GET /api/v1/farmers/{farmerId}` |
| Nhập kho | API sản phẩm, tồn kho, kho và `POST /api/v1/inventory-transactions/manual-adjustment` |
| Kho | API product variant và `GET /api/v1/inventories/by-variant/{id}` |
| Kiểm chất | `GET /api/v1/quality-inspections` |
| Kiểm kê | `POST /api/v1/stocktake` với một `warehouseId` và các dòng đếm thực tế |
| Giao hàng | Danh sách tồn theo sản phẩm, `GET /api/v1/customers` và `manual-adjustment` với số âm |
| Thông báo | `POST /api/v1/notification/me` (tải thủ công, chưa realtime) |
| Hồ sơ tài khoản | `GET /api/v1/auth/me` và `GET /api/v1/warehouse` |
| Xay xát | Danh sách, detail và `POST /api/v1/milling-orders/{id}/complete` |

## Giới hạn hiện tại

- API báo cáo đang ném `NotImplementedException`, nên màn báo cáo vẫn dùng data source local.
- API lịch sử giao dịch toàn kho trả HTTP 500, nên màn lịch sử vẫn dùng repository mock.
- Backend chưa có outbound/delivery-order controller; mobile dùng inventory adjustment để trừ tồn.
- Phiếu kiểm kê mobile được backend tự gán trạng thái `Draft`; client gửi
  `stockTakeStatusId: 0` nhưng backend không dùng ID này để quyết định trạng thái.
