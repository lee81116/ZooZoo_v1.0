
class CompanionService {
  static final List<String> _messages = [
    "今天也是美好的一天！加油！",
    "辛苦了！記得多喝水喔！",
    "慢慢開，安全第一！",
    "你是最棒的司機！",
    "累了嗎？休息一下再出發吧！",
    "祝你今天遇到很多好客人！",
    "ZooZoo 陪你一起努力！",
    "深呼吸，放輕鬆～",
    "記得保持微笑喔！",
    "無論如何，我都支持你！",
  ];

  String getRandomMessage() {
    return (_messages..shuffle()).first;
  }
}
