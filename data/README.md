# 测试数据与参考结果

| 文件 | 说明 |
|---|---|
| `style_cartoon_640x480.py` | **golden 参考实现**（本队自建），Kuwahara + 中值 + gamma/饱和度/量化的浮点版本 |
| `fortest.jpg` | 演示输入图，**本队成员自行拍摄**（可替换为任意自拍图） |
| `preview_kuwahara.png` | 6 宫格对比：输入 / 中值后 / Kuwahara(RTL) / Kuwahara(golden) / 全链路 / 差异图 |
| `preview_kuwahara_crop.png` | 同一区域的细节裁剪对比 |

> `preview_*.png` 由 `make_preview.py` 生成；`fortest.jpg` 仅用于演示与回归，替换后需重跑
> `verify_kuwahara.py` 与 `make_preview.py`。