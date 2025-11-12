const request = require("supertest");

// テスト全体で mongoose をモックし、Mongo 接続やモデルの副作用を排除する
jest.mock("mongoose", () => {
  const mockSort = jest.fn();
  const mockFind = jest.fn(() => ({ sort: mockSort }));
  const mockSave = jest.fn();

  class MockSchema {
    constructor(definition) {
      this.definition = definition; // スキーマ定義を保持するだけのダミークラス
    }
  }

  const Message = function (data) {
    this.save = () => mockSave(data); // 保存時に受け取ったデータを検証できるよう記録
  };
  Message.find = mockFind;

  return {
    connect: jest.fn(),
    Schema: MockSchema,
    model: jest.fn(() => Message),
    __mock: { mockFind, mockSort, mockSave },
  };
});

process.env.NODE_ENV = "test";
const mongoose = require("mongoose");
const { mockFind, mockSort, mockSave } = mongoose.__mock;
const { app } = require("../app");

const wizExerciseText = require("fs").readFileSync(
  require("path").join(__dirname, "..", "wizexercise.txt"),
  "utf-8"
);

describe("主要ルートの統合テスト", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockFind.mockReturnValue({ sort: mockSort });
  });

  it("GET / は最新順のメッセージを描画する", async () => {
    mockSort.mockResolvedValueOnce([
      { name: "Alice", message: "こんにちは", createdAt: new Date() },
    ]);

    const response = await request(app).get("/");

    expect(response.status).toBe(200);
    expect(mockFind).toHaveBeenCalled();
    expect(mockSort).toHaveBeenCalledWith({ createdAt: -1 });
    expect(response.text).toContain("Alice");
    expect(response.text).toContain("こんにちは");
  });

  it("GET / で MongoDB エラー時は 500 を返す", async () => {
    mockSort.mockRejectedValueOnce(new Error("mongo failure"));

    const response = await request(app).get("/");

    expect(response.status).toBe(500);
    expect(response.text).toBe("Error occurred");
  });

  it("POST /post はメッセージを保存してトップへリダイレクトする", async () => {
    mockSave.mockResolvedValueOnce();

    const response = await request(app)
      .post("/post")
      .type("form")
      .send({ name: "Bob", message: "テスト投稿" });

    expect(mockSave).toHaveBeenCalledWith({
      name: "Bob",
      message: "テスト投稿",
    });
    expect(response.status).toBe(302);
    expect(response.headers.location).toBe("/");
  });

  it("GET /wizfile はテキスト内容を HTML ラップで返す", async () => {
    const response = await request(app).get("/wizfile");

    expect(response.status).toBe(200);
    expect(response.text).toContain("<pre>");
    expect(response.text).toContain(wizExerciseText.trim().split("\n")[0]);
  });

  it("GET /wizexercise.txt はプレーンテキストで返す", async () => {
    const response = await request(app).get("/wizexercise.txt");

    expect(response.status).toBe(200);
    expect(response.headers["content-type"]).toContain("text/plain");
    expect(response.text.trim()).toBe(wizExerciseText.trim());
  });
});
