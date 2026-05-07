package com.mindhealth.backend.common;

public class Result {
    private int code;
    private String message;
    private Object data;
    private long timestamp;

    public static Result success(Object data) {
        Result result = new Result();
        result.code = 200;
        result.message = "操作成功";
        result.data = data;
        result.timestamp = System.currentTimeMillis();
        return result;
    }

    public static Result error(String message) {
        Result result = new Result();
        result.code = 400;
        result.message = message;
        result.data = null;
        result.timestamp = System.currentTimeMillis();
        return result;
    }

    // getter和setter方法
    public int getCode() {
        return code;
    }

    public void setCode(int code) {
        this.code = code;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public Object getData() {
        return data;
    }

    public void setData(Object data) {
        this.data = data;
    }

    public long getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(long timestamp) {
        this.timestamp = timestamp;
    }
}