const express= require("express")

const app = express()

app.get("/",(req,res)=>{
    res.send("send msg")
})

app.listen(8080,()=>{
    console.log("hello")
})