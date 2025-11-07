## 前置依赖

~~~sh
# 1. 目录: C:\core\common 下载所有依赖
## https://github.com/yt-dlp/yt-dlp/releases
## https://www.ffmpeg.org/
## https://github.com/aria2/aria2/
## https://github.com/shaka-project/shaka-packager/releases/latest
## https://github.com/yt-dlp/yt-dlp/

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a----        2023/11/15     19:21        5649408 aria2c.exe
-a----         2025/4/21     19:08      147789312 ffmpeg.exe
-a----         2025/11/7     14:07        5366272 shaka-packager.exe
-a----         2025/11/7     16:09       18345464 yt-dlp.exe

# 2. 将 C:\core\common 放进环境变量中

# 3. 测试
aria2c -v
packager --version
ffmpeg -version
yt-dlp -v

# 4. 将 main.py 文件中的 替换
- YTDLP_PATH = os.path.join(os.path.dirname(sys.executable), "yt-dlp.exe")
+ YTDLP_PATH = "yt-dlp.exe"
~~~

## 前置2
1. 使用 火狐浏览器 登录 google 和 udemy 账号
2. 火狐浏览器 安装插件(可以看 README.md 文件)
    - Mozilla Firefox: [Cookies Editor](https://cookie-editor.com/)
    - Mozilla Firefox: [Widevine L3 Decrypter](https://addons.mozilla.org/en-US/firefox/addon/widevine-l3-decrypter/)
3. 从 Cookies Editor 导出 Netscape 格式的数据 粘贴到 cookies.txt ,最后几行有 ud_user_jwt 复制 Bearer Token
4. 从 url 中 获取 课程ID 执行下载.

## 使用
~~~sh
# 仅下载字幕文件
python main.py -c <课程URL> -b <Token> --download-captions -l en --skip-lectures


# 仅下载课件文件
python main.py -c <课程URL> -b <Token> --download-assets --skip-lectures

# *++
python main.py -c https://www.udemy.com/course/yolo-masterclass-deep-learning-computer-vision-course/learn/lecture/34239592#overview  -b eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6MzEzNzQ5MjE5LCJlbWFpbCI6Imd1b3hpbmxlZTEyOUBnbWFpbC5jb20iLCJpc19zdXBlcnVzZXIiOmZhbHNlLCJncm91cF9pZHMiOltdfQ.OZcDRckR-jvuEK2G7a7GljJnBZaNCBppYXq26e1nPT4 --download-captions -l en --download-assets --skip-lectures --chapter "6"

# 下载所有课程+字幕+课件文件
## --skip-hls    如果失败，考虑直连mp4
## --chapter "6" 指定章节下载
## -o E:/2       指定输出目录 最好设置一个最短的，因为文件夹名有长度限制
python main.py -c url_id -b <你的Bearer Token> -q 1080 --download-captions -l en --download-assets
python main.py -c https://www.udemy.com/course/yolo-masterclass-deep-learning-computer-vision-course/learn/lecture/34239592#overview  -b eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6MzEzNzQ5MjE5LCJlbWFpbCI6Imd1b3hpbmxlZTEyOUBnbWFpbC5jb20iLCJpc19zdXBlcnVzZXIiOmZhbHNlLCJncm91cF9pZHMiOltdfQ.OZcDRckR-jvuEK2G7a7GljJnBZaNCBppYXq26e1nPT4 -q 1080 --download-captions -l en --download-assets --chapter "11" -o E:/2


！！！！下面的sh未经测试，因为额外发现了很多播放器支持字幕翻译
# 融合课程+字幕
## 测试单个视频（指定目录，不删除原文件）
merge_subs.bat "out_dir\ros2-advanced-core-concepts" -t
## 测试单个视频并替换原文件
merge_subs.bat "out_dir\ros2-advanced-core-concepts" -t -d
## 批量处理并替换原文件
merge_subs.bat "out_dir\ros2-advanced-core-concepts" -d

~~~


## 已经下载的记录
- Edouard Renard **加密**
    - [已下载] ROS2 Level 1 https://www.udemy.com/course/ros2-for-beginners/learn/lecture/20260476#overview
    - [已下载] ROS2 Level 2 https://www.udemy.com/course/ros2-tf-urdf-rviz-gazebo/learn/lecture/38688920#overview "253984580f21465099ef31e2e79259e4": "10ae7de21968458ebb4c398f8b033060",
    - [已下载] ROS2 Level 3 https://www.udemy.com/course/ros2-advanced-core-concepts/learn/lecture/40028718#content
    - [已下载] ROS2 Nav2+SLAM https://www.udemy.com/course/ros2-nav2-stack/learn/lecture/35488760#overview
- [已下载] JetsonNano https://www.udemy.com/course/jetson-nano-boot-camp/learn/lecture/29071724#overview
- [已下载] https://www.udemy.com/course/yolo-performance-improvement-masterclass/learn/lecture/40418738#overview
- [已下载] https://www.udemy.com/course/mastering-gpu-parallel-programming-with-cuda/learn/lecture/33558628#overview
- YOLOV11 [最推荐第一个]
    - [错误] **加密** eaec7a19ff6d49a099db0aede04c9d91:1a22a823216f5148e178f422975f2556
 https://www.udemy.com/course/yolo-masterclass-deep-learning-computer-vision-course/learn/lecture/34239592#overview 
    - 训练到部署 https://www.udemy.com/course/learn-tensorflow-pytorch-tensorrt-onnx-from-scratch/learn/lecture/38038938#overview
        - ONNX 和 TensorRT 优化边缘设备上的深度学习模型
- opencv + 深度学习
    - [下载中] **加密** 258f01983a7249c8a135c38ad824d9c0:b0ff69a8fdcc081fb156a76e83dc471b
 https://www.udemy.com/course/python-for-computer-vision-with-opencv-and-deep-learning/learn/lecture/12257438#overview

### 低优先级
- 树莓派 ROS2
    - https://www.udemy.com/course/robotics-with-ros-real-robot-using-raspberry-pi-and-opencv/