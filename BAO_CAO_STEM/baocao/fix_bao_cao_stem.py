# -*- coding: utf-8 -*-
"""Bổ sung phần thân mục 2.0 và 3.5 bị thiếu do trùng text với Mục lục."""

from docx import Document
from docx.shared import Pt, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_LINE_SPACING
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
from docx.text.paragraph import Paragraph

SRC = "_Bao_cao_tom_tat_ThuyCanh_IoT.docx"


def set_run_font(run, size_pt=13, bold=False, name="Times New Roman"):
    run.bold = bold
    run.font.name = name
    run._element.rPr.rFonts.set(qn("w:eastAsia"), name)
    run.font.size = Pt(size_pt)


def clear_and_write(p, text, size_pt=13, bold=False, align=WD_ALIGN_PARAGRAPH.JUSTIFY, space_after=6, first_line=True):
    p.alignment = align
    pf = p.paragraph_format
    pf.space_before = Pt(0)
    pf.space_after = Pt(space_after)
    pf.line_spacing_rule = WD_LINE_SPACING.ONE_POINT_FIVE
    pf.first_line_indent = Cm(1.0) if (first_line and align == WD_ALIGN_PARAGRAPH.JUSTIFY) else Pt(0)
    for r in list(p.runs):
        r._element.getparent().remove(r._element)
    run = p.add_run(text)
    set_run_font(run, size_pt=size_pt, bold=bold)
    return p


def insert_after(paragraph, text, size_pt=13, bold=False, align=WD_ALIGN_PARAGRAPH.JUSTIFY, space_after=6, first_line=True):
    new_p = OxmlElement("w:p")
    paragraph._element.addnext(new_p)
    new_para = Paragraph(new_p, paragraph._parent)
    clear_and_write(new_para, text, size_pt=size_pt, bold=bold, align=align, space_after=space_after, first_line=first_line)
    return new_para


def find_exact(doc, text, min_index=0):
    for i, p in enumerate(doc.paragraphs):
        if i < min_index:
            continue
        if p.text.strip() == text:
            return i, p
    raise KeyError(text)


def body_has(doc, needle, min_index=40):
    return any(needle in p.text for p in doc.paragraphs[min_index:])


def main():
    doc = Document(SRC)

    # Fix TOC numbering conflict: keep Kết luận/Hướng PT as 4/5; TLTH=6, PL=7
    for p in doc.paragraphs[:40]:
        t = p.text.strip()
        if t == "4. Tài liệu tham khảo":
            clear_and_write(p, "6. Tài liệu tham khảo (tiêu chí 4)", size_pt=12, bold=False,
                            align=WD_ALIGN_PARAGRAPH.LEFT, space_after=2, first_line=False)
        if t.startswith("7. Phụ lục"):
            clear_and_write(p, "7. Phụ lục báo cáo (tiêu chí 5)", size_pt=12, bold=False,
                            align=WD_ALIGN_PARAGRAPH.LEFT, space_after=2, first_line=False)

    # ---- Insert body 2.0 after II heading ----
    if not body_has(doc, "Phương án A – Trồng thủy canh thủ công"):
        _, p_ii = find_exact(doc, "II. THIẾT KẾ VÀ PHƯƠNG PHÁP NGHIÊN CỨU", min_index=40)
        blocks = [
            ("2.0. Tiêu chí giải pháp và lựa chọn phương án", True, WD_ALIGN_PARAGRAPH.LEFT, False),
            (
                "Theo các tiêu chí đã xác định ở Mục I, nhóm tiến hành tìm tòi và phân tích một số hướng giải pháp "
                "khác nhau trước khi chốt phương án khả thi:",
                False, WD_ALIGN_PARAGRAPH.JUSTIFY, True,
            ),
            (
                "- Phương án A – Trồng thủy canh thủ công (không IoT): chi phí thấp nhất nhưng không đáp ứng giám sát realtime, "
                "tự động hóa và mục tiêu giáo dục đo lường – điều khiển; loại vì thiếu tiêu chí chức năng và hiệu quả theo dõi.",
                False, WD_ALIGN_PARAGRAPH.JUSTIFY, False,
            ),
            (
                "- Phương án B – Mua hệ thủy canh thương mại tích hợp sẵn: tiện dùng nhưng giá cao, khó sửa, ít minh bạch nguyên lý, "
                "khó gắn vào bài học STEM “mở”; loại vì không đạt tiêu chí kinh tế và giáo dục.",
                False, WD_ALIGN_PARAGRAPH.JUSTIFY, False,
            ),
            (
                "- Phương án C – Dùng vi điều khiển không WiFi (Arduino Uno) + hiển thị LCD: đo được một số thông số tại chỗ "
                "nhưng thiếu giám sát từ xa và mở rộng app/AI; đạt một phần chức năng, chưa đạt tiêu chí giám sát realtime và mở rộng.",
                False, WD_ALIGN_PARAGRAPH.JUSTIFY, False,
            ),
            (
                "- Phương án D – Hệ IoT ESP32 + MQTT + app Flutter + tự động hóa bơm/đèn theo ngưỡng (phương án chọn): "
                "cân bằng tốt nhất giữa chức năng, giá thành, khả thi lắp ráp tại trường, giám sát từ xa và định hướng nâng cấp AI.",
                False, WD_ALIGN_PARAGRAPH.JUSTIFY, False,
            ),
            (
                "Bảng đối chiếu nhanh theo tiêu chí (mức đáp ứng: thấp / trung bình / cao):",
                False, WD_ALIGN_PARAGRAPH.JUSTIFY, True,
            ),
            (
                "- Chức năng đo – điều khiển: A thấp; B cao (đóng); C trung bình; D cao (mở, đủ kênh chính).",
                False, WD_ALIGN_PARAGRAPH.JUSTIFY, False,
            ),
            (
                "- Giám sát từ xa / app: A không; B tùy máy; C không hoặc rất hạn chế; D cao (MQTT realtime).",
                False, WD_ALIGN_PARAGRAPH.JUSTIFY, False,
            ),
            (
                "- Kinh tế & dễ bảo trì học đường: A cao về giá nhưng thiếu chức năng; B thấp; C trung bình; D cao.",
                False, WD_ALIGN_PARAGRAPH.JUSTIFY, False,
            ),
            (
                "- Giá trị STEM liên ngành: A thấp; B thấp; C trung bình; D cao.",
                False, WD_ALIGN_PARAGRAPH.JUSTIFY, False,
            ),
            (
                "Kết luận lựa chọn: nhóm chọn Phương án D làm giải pháp thiết kế. Từ đó triển khai bản thiết kế nguyên mẫu "
                "(cơ khí bồn/khung, sơ đồ đấu nối ESP32, firmware, quy trình công nghệ lắp ráp – hiệu chỉnh – vận hành) "
                "trình bày ở các mục 2.1 – 2.5 và thực hiện ở Mục III.",
                False, WD_ALIGN_PARAGRAPH.JUSTIFY, True,
            ),
        ]
        cur = p_ii
        for text, bold, align, first in blocks:
            cur = insert_after(cur, text, size_pt=13, bold=bold, align=align, first_line=first)
        print("Inserted body 2.0")
    else:
        print("Body 2.0 already present")

    # ---- Insert body 3.5 after hạn chế / before Ghi chú ----
    if not body_has(doc, "3.5. Hoàn thiện sản phẩm, thiết bị và quy trình công nghệ"):
        # Find Ghi chú in body
        anchor = None
        for i, p in enumerate(doc.paragraphs):
            if i < 100:
                continue
            if p.text.strip().startswith("Hạn chế còn tồn tại"):
                anchor = p
        if anchor is None:
            for i, p in enumerate(doc.paragraphs):
                if i < 100:
                    continue
                if p.text.strip().startswith("Ghi chú: Có thể chèn"):
                    # insert before by finding previous - use hạn chế alternative
                    pass
        if anchor is None:
            raise KeyError("Cannot find anchor for 3.5")

        blocks35 = [
            ("3.5. Hoàn thiện sản phẩm, thiết bị và quy trình công nghệ trong chế tạo – kiểm tra", True, WD_ALIGN_PARAGRAPH.LEFT, False),
            (
                "Trong quá trình chế tạo và thử nghiệm, nhóm không dừng ở lắp ráp một lần mà liên tục hoàn thiện nguyên mẫu:",
                False, WD_ALIGN_PARAGRAPH.JUSTIFY, True,
            ),
            (
                "- Hoàn thiện cơ khí: chỉnh vị trí HC-SR04 vuông góc mặt nước; cố định khung đèn LED và hộp điện để giảm rung, dễ bảo trì.",
                False, WD_ALIGN_PARAGRAPH.JUSTIFY, False,
            ),
            (
                "- Hoàn thiện đo lường: bổ sung lọc nhiễu median + Kalman 1D cho siêu âm sau khi phát hiện số đo mực nước dao động mạnh; hiệu chỉnh đối chiếu % hiển thị với mực nước thật.",
                False, WD_ALIGN_PARAGRAPH.JUSTIFY, False,
            ),
            (
                "- Hoàn thiện điều khiển: chốt ngưỡng FULL/LOW an toàn; ưu tiên tắt bơm khi LOW để tránh chạy khô; tách relay 2 kênh cho bơm và đèn.",
                False, WD_ALIGN_PARAGRAPH.JUSTIFY, False,
            ),
            (
                "- Hoàn thiện phần mềm: WiFi portal “ThuyCanh” thuận tiện cấu hình tại trường; chuẩn hóa topic MQTT theo chipId; app Flutter bổ sung các màn hình đăng nhập – chọn máy – dashboard – trạng thái AUTO.",
                False, WD_ALIGN_PARAGRAPH.JUSTIFY, False,
            ),
            (
                "- Hoàn thiện quy trình công nghệ: hệ thống hóa các bước Cơ khí → Cảm biến → Điện tử → Hiển thị → Cấu hình → Hiệu chỉnh thành quy trình lặp lại được, kèm bảng GPIO và biên bản kiểm tra theo điều kiện 1–6.",
                False, WD_ALIGN_PARAGRAPH.JUSTIFY, False,
            ),
            (
                "- Hoàn thiện hồ sơ: ảnh nguyên mẫu, ảnh app, sơ đồ, nhật ký thử nghiệm phục vụ thuyết trình cuộc thi và Phụ lục báo cáo.",
                False, WD_ALIGN_PARAGRAPH.JUSTIFY, False,
            ),
            (
                "Các vòng hoàn thiện trên chứng tỏ giải pháp không chỉ “chạy được lần đầu” mà còn được cải tiến dựa trên bằng chứng thử nghiệm, đúng yêu cầu của dự án kỹ thuật STEM.",
                False, WD_ALIGN_PARAGRAPH.JUSTIFY, True,
            ),
        ]
        cur = anchor
        for text, bold, align, first in blocks35:
            cur = insert_after(cur, text, size_pt=13, bold=bold, align=align, first_line=first)
        print("Inserted body 3.5")
    else:
        print("Body 3.5 already present")

    # Ensure note under references exists
    if not body_has(doc, "Hình thức trình bày theo dạng: Tên tác giả"):
        _, p_last = find_exact(doc, "8. Nhóm thực hiện. Mã nguồn firmware ThuyCanh_ESP32.ino và ứng dụng Flutter thư mục thuycanh/. Trường THPT Cát Hải, Hải Phòng, năm học 2025 – 2026.", min_index=150)
        insert_after(
            p_last,
            "Ghi chú: Các tài liệu trên được nhóm nghiên cứu trong quá trình xác định vấn đề, lựa chọn giải pháp, thiết kế và chế tạo. "
            "Hình thức trình bày theo dạng: Tên tác giả. Tên tài liệu. Nơi xuất bản, năm xuất bản (kèm đường dẫn nếu là nguồn trực tuyến).",
            size_pt=12, bold=False, first_line=True,
        )
        print("Inserted ref note")

    doc.save(SRC)

    # verify
    d2 = Document(SRC)
    blob_body = "\n".join(p.text for p in d2.paragraphs[40:])
    checks = [
        "Phương án A – Trồng thủy canh thủ công",
        "Phương án D – Hệ IoT ESP32",
        "2.0. Tiêu chí giải pháp và lựa chọn phương án",
        "3.5. Hoàn thiện sản phẩm, thiết bị và quy trình công nghệ",
        "Hoàn thiện đo lường",
        "Điều kiện 1 – Mực nước thay đổi",
        "1.1. Tiêu chí cho giải pháp",
        "Resh, H. M.",
        "Phụ lục E",
    ]
    for c in checks:
        print(("OK" if c in blob_body else "MISSING"), c)

    # TOC check
    toc = "\n".join(p.text for p in d2.paragraphs[:35])
    print("TOC TLTH:", "6. Tài liệu tham khảo" in toc)
    print("TOC PL:", "7. Phụ lục báo cáo" in toc)


if __name__ == "__main__":
    main()
