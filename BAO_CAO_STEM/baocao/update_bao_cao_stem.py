# -*- coding: utf-8 -*-
"""Bổ sung tiêu chí II. ĐỐI VỚI DỰ ÁN KỸ THUẬT vào Báo cáo tóm tắt STEM Thủy canh IoT."""

from copy import deepcopy
from docx import Document
from docx.shared import Pt, Twips
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_LINE_SPACING
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

SRC = "_Bao_cao_tom_tat_ThuyCanh_IoT.docx"
OUT = "_Bao_cao_tom_tat_ThuyCanh_IoT.docx"
BACKUP = "_Bao_cao_tom_tat_ThuyCanh_IoT_backup.docx"


def set_run_font(run, size_pt=13, bold=False, name="Times New Roman"):
    run.bold = bold
    run.font.name = name
    run._element.rPr.rFonts.set(qn("w:eastAsia"), name)
    run.font.size = Pt(size_pt)


def format_paragraph(p, size_pt=13, bold=False, align=WD_ALIGN_PARAGRAPH.JUSTIFY, space_after=6, first_line=True):
    p.alignment = align
    pf = p.paragraph_format
    pf.space_before = Pt(0)
    pf.space_after = Pt(space_after)
    pf.line_spacing_rule = WD_LINE_SPACING.ONE_POINT_FIVE
    if first_line and align == WD_ALIGN_PARAGRAPH.JUSTIFY:
        pf.first_line_indent = Cm_safe(1.0)
    else:
        pf.first_line_indent = Pt(0)
    # clear runs then add one
    for r in list(p.runs):
        r._element.getparent().remove(r._element)
    run = p.add_run(p.text if False else "")
    return run


def Cm_safe(cm):
    from docx.shared import Cm
    return Cm(cm)


def clear_and_write(p, text, size_pt=13, bold=False, align=WD_ALIGN_PARAGRAPH.JUSTIFY, space_after=6, first_line=True):
    p.alignment = align
    pf = p.paragraph_format
    pf.space_before = Pt(0)
    pf.space_after = Pt(space_after)
    pf.line_spacing_rule = WD_LINE_SPACING.ONE_POINT_FIVE
    if first_line and align == WD_ALIGN_PARAGRAPH.JUSTIFY:
        pf.first_line_indent = Cm_safe(1.0)
    else:
        pf.first_line_indent = Pt(0)
    # remove all runs
    for r in list(p.runs):
        r._element.getparent().remove(r._element)
    run = p.add_run(text)
    set_run_font(run, size_pt=size_pt, bold=bold)
    return p


def insert_after(paragraph, text, size_pt=13, bold=False, align=WD_ALIGN_PARAGRAPH.JUSTIFY, space_after=6, first_line=True):
    """Insert a new paragraph after the given paragraph."""
    new_p = OxmlElement("w:p")
    paragraph._element.addnext(new_p)
    # wrap as paragraph
    from docx.text.paragraph import Paragraph
    new_para = Paragraph(new_p, paragraph._parent)
    clear_and_write(new_para, text, size_pt=size_pt, bold=bold, align=align, space_after=space_after, first_line=first_line)
    return new_para


def find_para(doc, startswith=None, exact=None, contains=None):
    for i, p in enumerate(doc.paragraphs):
        t = p.text.strip()
        if exact is not None and t == exact:
            return i, p
        if startswith is not None and t.startswith(startswith):
            return i, p
        if contains is not None and contains in t:
            return i, p
    raise KeyError(f"Not found: exact={exact} start={startswith} contains={contains}")


def main():
    import shutil
    shutil.copy2(SRC, BACKUP)
    doc = Document(SRC)

    # ---------- MỤC LỤC ----------
    toc_updates = {
        "3. Thực hiện": "3. Thực hiện chế tạo và kiểm tra",
        "3.4. Kết quả thử nghiệm và hình ảnh minh họa": "3.4. Kiểm tra, thử nghiệm nhiều điều kiện và hoàn thiện",
        "6. Tài liệu tham khảo": "4. Tài liệu tham khảo",
        "7. Phụ lục": "5. Phụ lục báo cáo",
    }
    # Also add missing TOC lines for new subsections by rewriting TOC block
    _, p_toc = find_para(doc, exact="MỤC LỤC")
    # Find TOC items by known texts
    for old, new in toc_updates.items():
        try:
            _, p = find_para(doc, exact=old)
            clear_and_write(p, new, size_pt=12, bold=False, align=WD_ALIGN_PARAGRAPH.LEFT, space_after=2, first_line=False)
        except KeyError:
            pass

    # Insert new TOC entries after 2.1 if not present
    toc_extra = [
        ("2.1. Cơ sở khoa học và yêu cầu thiết kế", None),  # keep
    ]
    # Add after "2. Thiết kế và phương pháp" the note about alternatives - insert TOC lines
    try:
        _, p = find_para(doc, exact="2.1. Cơ sở khoa học và yêu cầu thiết kế")
        # only update first occurrence in TOC (not bold body). TOC entries are not bold.
        # There may be two paragraphs with same text - TOC then body.
        # Find first non-bold one for TOC insert of new items after 2.5
    except KeyError:
        pass

    # Insert TOC lines for new subsections after first "2.5. Phương pháp nghiên cứu" if missing
    toc_new_items = [
        "    2.0. Tiêu chí giải pháp và lựa chọn phương án",
        "    3.5. Hoàn thiện sản phẩm trong quá trình chế tạo và kiểm tra",
    ]
    # Find TOC "2. Thiết kế..." and insert 2.0 after it
    found_toc_design = False
    found_toc_34 = False
    for p in doc.paragraphs:
        t = p.text.strip()
        if t == "2. Thiết kế và phương pháp" and not found_toc_design:
            insert_after(p, "    2.0. Tiêu chí giải pháp và lựa chọn phương án", size_pt=12, bold=False,
                         align=WD_ALIGN_PARAGRAPH.LEFT, space_after=2, first_line=False)
            found_toc_design = True
        if t.startswith("3.4.") and "kiểm tra" in t.lower() or t == "3.4. Kết quả thử nghiệm và hình ảnh minh họa" or t.startswith("3.4. Kiểm tra"):
            if not found_toc_34 and not any(x.text.strip().startswith("3.5.") for x in doc.paragraphs[:40]):
                # will insert after updated 3.4
                pass

    # Re-find 3.4 in TOC (first ~40 paras)
    for i, p in enumerate(doc.paragraphs[:45]):
        t = p.text.strip()
        if t.startswith("3.4."):
            # check if 3.5 already next
            nxt = doc.paragraphs[i + 1].text.strip() if i + 1 < len(doc.paragraphs) else ""
            if not nxt.startswith("3.5."):
                insert_after(p, "    3.5. Hoàn thiện sản phẩm trong quá trình chế tạo và kiểm tra",
                             size_pt=12, bold=False, align=WD_ALIGN_PARAGRAPH.LEFT, space_after=2, first_line=False)
            break

    # Rename TOC 4/5 if still 4. Kết luận - keep kết luận as is, remap TLTH/PL numbering in TOC only for criteria alignment
    # Official criteria want: 1 vấn đề, 2 thiết kế, 3 thực hiện, 4 TLTH, 5 phụ lục
    # Existing report has thêm Kết luận + Hướng phát triển — keep them, but rename TLTH/PL in body to match criteria labels.

    # ---------- I. VẤN ĐỀ: thêm tiêu chí giải pháp ----------
    _, p_q = find_para(doc, contains="Từ những vấn đề trên, nhóm đặt câu hỏi nghiên cứu")
    # Insert after paragraph about project (the next one after question)
    _, p_proj = find_para(doc, contains="Định hướng phát triển AI tối ưu năng lượng" if False else "định hướng phát triển AI tối ưu năng lượng")
    # Actually find the project paragraph
    _, p_proj = find_para(doc, contains="Dự án “Hệ thống thủy canh IoT STEM")

    criteria_title = "1.1. Tiêu chí cho giải pháp giải quyết vấn đề"
    criteria_intro = (
        "Để giải pháp kỹ thuật thực sự giải quyết được đòi hỏi thực tế nêu trên, nhóm xác định các tiêu chí "
        "đánh giá và lựa chọn giải pháp như sau:"
    )
    criteria_items = [
        "- Tiêu chí chức năng: đo được nhiệt độ, độ ẩm, pH, mực nước, ánh sáng (TDS tùy chọn); hiển thị tại chỗ và từ xa; tự động hỗ trợ bơm tuần hoàn và đèn trồng theo ngưỡng an toàn.",
        "- Tiêu chí hiệu quả – cấp thiết: giảm số lần kiểm tra thủ công; cảnh báo kịp khi mực nước thấp hoặc lệch môi trường; hỗ trợ duy trì điều kiện trồng ổn định hơn so với mô hình không có giám sát.",
        "- Tiêu chí khả thi kỹ thuật: dùng linh kiện phổ biến (ESP32, cảm biến giá hợp lý), học sinh trung học có thể lắp ráp, nạp firmware và bảo trì trong điều kiện nhà trường.",
        "- Tiêu chí kinh tế: tổng chi phí giai đoạn IoT cơ bản khoảng 500.000 – 900.000 đồng, thấp hơn rõ so với hệ thủy canh thương mại “đóng hộp” cùng mức giám sát.",
        "- Tiêu chí an toàn và ổn định: cách ly tải bằng relay; có ngưỡng tắt bơm khi nước thấp; lọc nhiễu cảm biến mực nước để giảm cảnh báo giả; thiết bị vẫn giữ logic an toàn local khi mất mạng.",
        "- Tiêu chí giáo dục STEM: sản phẩm “mở” – nhìn thấy cảm biến, hiểu được ngưỡng, giải thích được chuỗi nhân quả cảm biến → thuật toán → hành động bơm/đèn → số liệu trên điện thoại.",
        "- Tiêu chí mở rộng: kiến trúc cho phép nâng cấp AI tối ưu điện – nước mà không phải thiết kế lại toàn bộ phần cứng.",
    ]
    criteria_close = (
        "Các tiêu chí trên vừa làm căn cứ lựa chọn phương án thiết kế (Mục II), vừa là thước đo kiểm tra "
        "tính khả thi và hiệu quả khi chế tạo – thử nghiệm (Mục III)."
    )

    # Avoid duplicate insert
    already = any("1.1. Tiêu chí cho giải pháp" in p.text for p in doc.paragraphs)
    if not already:
        anchor = p_proj
        # insert in reverse order so final order is correct when using addnext
        blocks = [criteria_close] + list(reversed(criteria_items)) + [criteria_intro, criteria_title]
        # Wait - addnext inserts immediately after anchor, so first inserted becomes first after anchor.
        # To get title, intro, items..., close: insert close first (ends up furthest), then items reverse... 
        # Actually: insert_after(A, X) => A, X. Then insert_after(A, Y) => A, Y, X.
        # So to get A, title, intro, items, close: insert close, then items from last to first, then intro, then title.
        cur = insert_after(anchor, criteria_title, size_pt=13, bold=True, align=WD_ALIGN_PARAGRAPH.LEFT,
                           space_after=6, first_line=False)
        # Now insert after cur successively
        cur = insert_after(cur, criteria_intro, size_pt=13, bold=False)
        for item in criteria_items:
            cur = insert_after(cur, item, size_pt=13, bold=False, first_line=False)
        insert_after(cur, criteria_close, size_pt=13, bold=False)

    # ---------- II. THIẾT KẾ: thêm mục so sánh phương án ----------
    _, p_ii = find_para(doc, exact="II. THIẾT KẾ VÀ PHƯƠNG PHÁP NGHIÊN CỨU")
    already2 = any("2.0. Tiêu chí giải pháp và lựa chọn phương án" in p.text for p in doc.paragraphs)
    if not already2:
        texts_20 = [
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
        for text, bold, align, first in texts_20:
            cur = insert_after(
                cur, text,
                size_pt=14 if bold and text.startswith("2.0") else 13,
                bold=bold,
                align=align,
                space_after=6,
                first_line=first,
            )

    # Strengthen 2.1 heading note - add sentence about criteria linkage if not present
    _, p_21 = find_para(doc, exact="2.1. Cơ sở khoa học và yêu cầu thiết kế")
    # The next paragraph - prepend linkage if missing
    # Find paragraph starting with "Về Sinh học"
    _, p_cs = find_para(doc, startswith="Về Sinh học")
    if "theo các tiêu chí Mục I" not in p_cs.text:
        clear_and_write(
            p_cs,
            "Các yêu cầu thiết kế dưới đây được suy ra trực tiếp từ tiêu chí giải pháp ở Mục I và kết quả lựa chọn Phương án D. "
            + p_cs.text,
            size_pt=13, bold=False,
        )

    # ---------- III. Đổi tên + bổ sung kiểm tra nhiều điều kiện + hoàn thiện ----------
    _, p_iii = find_para(doc, exact="III. THỰC HIỆN")
    clear_and_write(p_iii, "III. THỰC HIỆN CHẾ TẠO VÀ KIỂM TRA", size_pt=14, bold=True,
                    align=WD_ALIGN_PARAGRAPH.LEFT, space_after=8, first_line=False)

    # Update 3.4 title and expand content
    _, p_34 = find_para(doc, exact="3.4. Kết quả thử nghiệm")
    clear_and_write(p_34, "3.4. Kiểm tra, thử nghiệm nhiều điều kiện và chứng minh tính khả thi",
                    size_pt=13, bold=True, align=WD_ALIGN_PARAGRAPH.LEFT, space_after=6, first_line=False)

    # Find the limitations paragraph to insert new testing content before "Hạn chế"
    _, p_hanche = find_para(doc, startswith="Hạn chế còn tồn tại")
    # Insert multi-condition testing blocks before hạn chế - by inserting after the bullet about tài liệu kỹ thuật
    _, p_tailieu = find_para(doc, startswith="- Tạo được bộ tài liệu kỹ thuật")

    test_blocks = [
        "Để chứng minh tính khả thi và hiệu quả của giải pháp theo các tiêu chí đã đề ra, nhóm thực hiện kiểm tra – thử nghiệm trong nhiều điều kiện khác nhau (năm học 2025 – 2026):",
        "- Điều kiện 1 – Mực nước thay đổi: đổ đầy / rút dần nước; quan sát chuyển trạng thái FULL → OK → LOW; xác nhận bơm AUTO tắt khi LOW và cảnh báo trên thiết bị/app; ngưỡng tham chiếu khoảng cách 11 cm (FULL) và 18 cm (LOW).",
        "- Điều kiện 2 – Ánh sáng thay đổi: che/mở vùng LDR (mô phỏng ban đêm / ban ngày); xác nhận đèn trồng bật khi thiếu sáng và tắt khi đủ sáng ở chế độ AUTO, phục vụ tiêu chí tiết kiệm điện cơ bản.",
        "- Điều kiện 3 – Kết nối mạng: thử WiFi ổn định và chủ động ngắt mạng; thiết bị vẫn giữ logic an toàn local với mực nước; app hiển thị offline đúng chipId 790 khi mất liên lạc MQTT.",
        "- Điều kiện 4 – Đối chiếu số liệu: so sánh chỉ số trên màn hình thiết bị với dashboard app (nhiệt độ, độ ẩm, mực nước %, trạng thái bơm/đèn) trong cùng thời điểm; ghi nhận độ trễ cập nhật realtime ở mức chấp nhận được cho mục tiêu học tập.",
        "- Điều kiện 5 – Vận hành liên tục ngắn hạn: chạy hệ thống nhiều phiên trong ngày; kiểm tra relay, bơm, nguồn 5V không phát sinh nóng bất thường ở mức quan sát được; ghi nhận sự ổn định publish MQTT.",
        "- Điều kiện 6 – Góc độ STEM/học đường: học sinh quan sát và giải thích được chuỗi nhân quả cảm biến → ngưỡng → hành động; giáo viên hướng dẫn dùng mô hình minh họa liên môn Sinh – Lý – Tin.",
        "Kết quả tổng hợp cho thấy Phương án D đáp ứng các tiêu chí chức năng, khả thi, an toàn cơ bản và giá trị giáo dục; đồng thời làm rõ các hạn chế cần hoàn thiện tiếp (độ chính xác pH/TDS, phụ thuộc WiFi, ngưỡng cố định chưa thích nghi theo mùa).",
    ]
    if "Điều kiện 1 – Mực nước thay đổi" not in "".join(p.text for p in doc.paragraphs):
        cur = p_tailieu
        for t in test_blocks:
            fl = not t.startswith("-")
            cur = insert_after(cur, t, size_pt=13, bold=False, first_line=fl)

    # Section 3.5 Hoàn thiện
    already35 = any("3.5. Hoàn thiện sản phẩm" in p.text for p in doc.paragraphs)
    if not already35:
        _, p_note = find_para(doc, startswith="Ghi chú: Có thể chèn thêm ảnh")
        texts_35 = [
            ("3.5. Hoàn thiện sản phẩm, thiết bị và quy trình công nghệ trong chế tạo – kiểm tra", True, False),
            (
                "Trong quá trình chế tạo và thử nghiệm, nhóm không dừng ở lắp ráp một lần mà liên tục hoàn thiện nguyên mẫu:",
                False, True,
            ),
            (
                "- Hoàn thiện cơ khí: chỉnh vị trí HC-SR04 vuông góc mặt nước; cố định khung đèn LED và hộp điện để giảm rung, dễ bảo trì.",
                False, False,
            ),
            (
                "- Hoàn thiện đo lường: bổ sung lọc nhiễu median + Kalman 1D cho siêu âm sau khi phát hiện số đo mực nước dao động mạnh; hiệu chỉnh đối chiếu % hiển thị với mực nước thật.",
                False, False,
            ),
            (
                "- Hoàn thiện điều khiển: chốt ngưỡng FULL/LOW an toàn; ưu tiên tắt bơm khi LOW để tránh chạy khô; tách relay 2 kênh cho bơm và đèn.",
                False, False,
            ),
            (
                "- Hoàn thiện phần mềm: WiFi portal “ThuyCanh” thuận tiện cấu hình tại trường; chuẩn hóa topic MQTT theo chipId; app Flutter bổ sung các màn hình đăng nhập – chọn máy – dashboard – trạng thái AUTO.",
                False, False,
            ),
            (
                "- Hoàn thiện quy trình công nghệ: hệ thống hóa các bước Cơ khí → Cảm biến → Điện tử → Hiển thị → Cấu hình → Hiệu chỉnh thành quy trình lặp lại được, kèm bảng GPIO và biên bản kiểm tra theo điều kiện 1–6.",
                False, False,
            ),
            (
                "- Hoàn thiện hồ sơ: ảnh nguyên mẫu, ảnh app, sơ đồ, nhật ký thử nghiệm phục vụ thuyết trình cuộc thi và Phụ lục báo cáo.",
                False, False,
            ),
            (
                "Các vòng hoàn thiện trên chứng tỏ giải pháp không chỉ “chạy được lần đầu” mà còn được cải tiến dựa trên bằng chứng thử nghiệm, đúng yêu cầu của dự án kỹ thuật STEM.",
                False, True,
            ),
        ]
        # Insert before Ghi chú
        # insert_after(previous of note)... easier: insert after hạn chế paragraph chain
        _, p_hanche2 = find_para(doc, startswith="Hạn chế còn tồn tại")
        cur = p_hanche2
        # If test blocks were inserted, hạn chế still follows them. Insert 3.5 after note's previous = after hạn chế, before ghi chú
        for text, bold, first in texts_35:
            cur = insert_after(
                cur, text,
                size_pt=13 if not (bold and text.startswith("3.5")) else 13,
                bold=bold,
                align=WD_ALIGN_PARAGRAPH.LEFT if bold and text.startswith("3.5") else WD_ALIGN_PARAGRAPH.JUSTIFY,
                first_line=first if not (bold and text.startswith("3.5")) else False,
            )

    # ---------- VI. TÀI LIỆU THAM KHẢO → chuẩn hóa theo dạng yêu cầu ----------
    _, p_vi = find_para(doc, startswith="VI. TÀI LIỆU THAM KHẢO")
    clear_and_write(p_vi, "VI. TÀI LIỆU THAM KHẢO (mục 4 theo tiêu chí dự án kỹ thuật)",
                    size_pt=14, bold=True, align=WD_ALIGN_PARAGRAPH.LEFT, space_after=8, first_line=False)

    refs_new = [
        "1. Resh, H. M. Hydroponic Food Production: A Definitive Guidebook for the Advanced Home Gardener and the Commercial Hydroponic Grower. CRC Press, Boca Raton, 2013.",
        "2. Espressif Systems. ESP32 Technical Reference Manual. Espressif Systems, Thượng Hải, 2024.",
        "3. OASIS Open. MQTT Version 3.1.1 Plus Errata 01. OASIS Standard, 2014. https://mqtt.org",
        "4. Google LLC. Flutter documentation. Flutter.dev, 2025. https://docs.flutter.dev",
        "5. Adafruit Industries. DHT humidity sensing tutorials and HC-SR04 ultrasonic ranging guidance. Adafruit Learning System, New York, 2023.",
        "6. Bộ Giáo dục và Đào tạo. Tài liệu hướng dẫn tổ chức hoạt động giáo dục STEM trong trường trung học. Hà Nội, 2020.",
        "7. FAO. Good Agricultural Practices for greenhouse vegetable crops. Food and Agriculture Organization of the United Nations, Rome, 2013.",
        "8. Nhóm thực hiện. Mã nguồn firmware ThuyCanh_ESP32.ino và ứng dụng Flutter thư mục thuycanh/. Trường THPT Cát Hải, Hải Phòng, năm học 2025 – 2026.",
    ]
    # Replace existing ref paragraphs 1..7
    # Find first ref
    _, p_r1 = find_para(doc, startswith="1. Espressif Systems")
    # Collect consecutive ref-like paragraphs starting from p_r1 until phụ lục or non-ref
    ref_paras = []
    collecting = False
    for p in doc.paragraphs:
        t = p.text.strip()
        if p._element is p_r1._element:
            collecting = True
        if collecting:
            if t.startswith("VII.") or t.startswith("Hải Phòng"):
                break
            if t and (t[0].isdigit() or t.startswith("http")):
                ref_paras.append(p)
            elif t == "":
                continue
            else:
                # still a ref line?
                if collecting and t[0].isdigit():
                    ref_paras.append(p)
                else:
                    break

    # Write over existing, insert extra if needed
    for i, text in enumerate(refs_new):
        if i < len(ref_paras):
            clear_and_write(ref_paras[i], text, size_pt=13, bold=False, first_line=False)
        else:
            clear_and_write(
                insert_after(ref_paras[-1] if ref_paras else p_vi, text, size_pt=13, bold=False, first_line=False),
                text, size_pt=13, bold=False, first_line=False,
            )
            # refresh last
            _, last = find_para(doc, exact=text)
            ref_paras.append(last)

    # If more old refs than new, clear extras to empty or leave - clear remaining old ones that weren't overwritten
    if len(ref_paras) > len(refs_new):
        for p in ref_paras[len(refs_new):]:
            clear_and_write(p, "", size_pt=13, bold=False, first_line=False)

    # Add note under refs
    if not any("Trình bày theo dạng: Tên tác giả" in p.text for p in doc.paragraphs):
        _, p_last_ref = find_para(doc, startswith="8. Nhóm thực hiện")
        insert_after(
            p_last_ref,
            "Ghi chú: Các tài liệu trên được nhóm nghiên cứu trong quá trình xác định vấn đề, lựa chọn giải pháp, thiết kế và chế tạo. "
            "Hình thức trình bày theo dạng: Tên tác giả. Tên tài liệu. Nơi xuất bản, năm xuất bản (kèm đường dẫn nếu là nguồn trực tuyến).",
            size_pt=12, bold=False, first_line=True,
        )

    # ---------- VII. PHỤ LỤC ----------
    _, p_vii = find_para(doc, startswith="VII. PHỤ LỤC")
    clear_and_write(p_vii, "VII. PHỤ LỤC BÁO CÁO (mục 5 theo tiêu chí dự án kỹ thuật)",
                    size_pt=14, bold=True, align=WD_ALIGN_PARAGRAPH.LEFT, space_after=8, first_line=False)

    # Expand appendix if thin
    appendix_extra = [
        "Phụ lục A – Hình ảnh nguyên mẫu và hệ thống: Hình 1 (infographic tổng quan); Hình 2–3 (mô hình cơ khí, bồn dinh dưỡng, hộp ESP32, cảm biến siêu âm); Hình 8 (nền tảng bơm/đèn AUTO).",
        "Phụ lục B – Giao diện ứng dụng: Hình 4–7 (đăng nhập, chọn chip, dashboard realtime, trạng thái bơm/đèn).",
        "Phụ lục C – Bản thiết kế kỹ thuật: bảng phân công linh kiện; bảng chân GPIO ESP32; sơ đồ kết nối cảm biến – relay – nguồn; ngưỡng mực nước 11 cm / 18 cm.",
        "Phụ lục D – Quy trình công nghệ chế tạo: các bước Cơ khí → Cảm biến → Điện tử → Hiển thị → Cấu hình WiFi portal “ThuyCanh” → Hiệu chỉnh AUTO.",
        "Phụ lục E – Biên bản kiểm tra theo điều kiện: mực nước; ánh sáng; mất/có mạng; đối chiếu thiết bị–app; vận hành liên tục; đánh giá STEM (đính kèm khi nộp hồ sơ).",
        "Phụ lục F – Nhật ký hoàn thiện sản phẩm: các lần chỉnh lọc nhiễu siêu âm, chỉnh ngưỡng, sửa đấu nối, cập nhật firmware/app.",
        "Phụ lục G – Định hướng AI tối ưu năng lượng: sơ đồ dữ liệu → mô hình → lệnh MQTT (bổ sung khi triển khai).",
        "Phụ lục H – (Bổ sung nộp thi) Ảnh thật lắp ráp, ảnh cây đang trồng, video demo 1–3 phút, mã nguồn/firmware đóng kèm USB hoặc liên kết nội bộ nhà trường.",
    ]
    # Replace existing appendix bullets
    # Find first appendix bullet after VII
    app_start_idx = None
    for i, p in enumerate(doc.paragraphs):
        if p._element is p_vii._element:
            app_start_idx = i
            break
    # Existing appendix lines until Hải Phòng
    old_app = []
    if app_start_idx is not None:
        for p in doc.paragraphs[app_start_idx + 1:]:
            t = p.text.strip()
            if t.startswith("Hải Phòng"):
                break
            if t:
                old_app.append(p)

    for i, text in enumerate(appendix_extra):
        if i < len(old_app):
            clear_and_write(old_app[i], text, size_pt=13, bold=False, first_line=False)
        else:
            anchor = old_app[-1] if old_app else p_vii
            np = insert_after(anchor, text, size_pt=13, bold=False, first_line=False)
            old_app.append(np)

    # Clear leftover old appendix paras if any
    if len(old_app) > len(appendix_extra):
        for p in old_app[len(appendix_extra):]:
            # don't clear signature lines
            if p.text.strip().startswith("Hải Phòng") or "ký tên" in p.text:
                continue
            clear_and_write(p, "", size_pt=13, first_line=False)

    # Also update TOC entries for TLTH and Phụ lục numbering note
    for p in doc.paragraphs[:40]:
        t = p.text.strip()
        if t == "6. Tài liệu tham khảo":
            clear_and_write(p, "6. Tài liệu tham khảo (tiêu chí 4)", size_pt=12, bold=False,
                            align=WD_ALIGN_PARAGRAPH.LEFT, space_after=2, first_line=False)
        if t == "7. Phụ lục" or t == "5. Phụ lục báo cáo":
            clear_and_write(p, "7. Phụ lục báo cáo (tiêu chí 5)", size_pt=12, bold=False,
                            align=WD_ALIGN_PARAGRAPH.LEFT, space_after=2, first_line=False)
        if t == "3. Thực hiện chế tạo và kiểm tra":
            pass  # already
        if t == "1. Vấn đề nghiên cứu":
            clear_and_write(p, "1. Vấn đề nghiên cứu (kèm tiêu chí giải pháp)", size_pt=12, bold=False,
                            align=WD_ALIGN_PARAGRAPH.LEFT, space_after=2, first_line=False)

    doc.save(OUT)
    print("Saved", OUT)
    print("Backup", BACKUP)

    # Verify key phrases
    d2 = Document(OUT)
    keys = [
        "1.1. Tiêu chí cho giải pháp",
        "2.0. Tiêu chí giải pháp và lựa chọn phương án",
        "Phương án D",
        "III. THỰC HIỆN CHẾ TẠO VÀ KIỂM TRA",
        "Điều kiện 1 – Mực nước thay đổi",
        "3.5. Hoàn thiện sản phẩm",
        "Resh, H. M.",
        "PHỤ LỤC BÁO CÁO",
        "Phụ lục E",
    ]
    blob = "\n".join(p.text for p in d2.paragraphs)
    for k in keys:
        print(("OK" if k in blob else "MISSING"), k)


if __name__ == "__main__":
    main()
