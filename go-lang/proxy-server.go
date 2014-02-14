package main
 
import (
    "net"
    "fmt"
    "io"
    "bytes"
    "encoding/binary"
)

type Methods struct{
    ver, nmethods uint8
    methods uint8
}

type proxyConn struct {
    conn    net.Conn
}

func (c *proxyConn) readMethods() Methods {
    var m Methods

    b := make([]byte, 1024)
    n, err := c.conn.Read(b)
    if err != nil && err != io.EOF { panic(err) }

    buf := bytes.NewBuffer(b[0:n])

    err = binary.Read(buf, binary.LittleEndian, &m.ver)
    if err != nil {
        fmt.Println("binary.Read failed:", err)
    }

    err = binary.Read(buf, binary.LittleEndian, &m.nmethods)
    if err != nil {
        fmt.Println("binary.Read failed:", err)
    }

    err = binary.Read(buf, binary.BigEndian, &m.methods)
    if err != nil {
        fmt.Println("binary.Read failed:", err)
    }
    fmt.Println("read method:")
    fmt.Println(m)
    return m
}

func (c *proxyConn) returnMethod() {
    buf := make([]byte, 2)
    buf[0] = 5
    buf[1] = 0
    c.conn.Write(buf)
    fmt.Println("return method:")
    fmt.Println(buf)
}

func (c *proxyConn) service() {
    buf := make([]byte, 128)

    n, err := c.conn.Read(buf)
    if err != nil && err != io.EOF { panic(err) }
    fmt.Println(buf[:n])

    var s string
    var t string
    var i int
    if(buf[3] == 3){//domail
        for i = 4; i < n-2; i++ {
            s += fmt.Sprintf("%c", buf[i])
        }
    } else {//ip4 or ip6
        s += fmt.Sprintf("%d", buf[4])
        for i = 5; i < n-2; i++ {
            s += fmt.Sprintf(".%d", buf[i])
        }
    }

    p := make([]byte, 2)
    var port uint16
    p[1] = buf[n-1]
    p[0] = buf[n-2]
    b := bytes.NewBuffer(p)
    err = binary.Read(b, binary.BigEndian, &port)
    if err != nil {
        fmt.Println("binary.Read failed:", err)
    }

    s += fmt.Sprintf(":%d", port)


    switch buf[1] {
        case 1://TCP
            t = "tcp"
        case 2://BIND
        case 3://UDP
            t = "udp"
    }

    conn, err := net.Dial(t, s)
    if err != nil {
        fmt.Printf("%s connect error %s\n", t, s)
        buf[1] = 4 //X’00′ succeeded X’01′ general SOCKS server failure X’02′ connection not allowed by ruleset X’03′ Network unreachable X’04′ Host unreachable
                   //rfc1928
        c.conn.Write(buf[:n])
        c.conn.Close()
        return
    }
    buf[1] = 0
    c.conn.Write(buf[:n])
    fmt.Printf("%s connect success %s\n", t, s)
    go serv(conn, c.conn)
    go serv(c.conn, conn)
}

func serv(in net.Conn, out net.Conn){
    b := make([]byte, 10240)
    for ;;{
        n, err := in.Read(b)
        if( err != nil ){
            fmt.Printf("close\n")
            in.Close()
            out.Close()
            return
        }
        fmt.Printf("serv %d\n", n)
        out.Write(b[:n]);
    }

}

func ProxyConn(conn net.Conn ){
    c := &proxyConn{conn}

    m := c.readMethods()
    fmt.Println(m)

    c.returnMethod()

    c.service()
}

func main() {
    ln, err := net.Listen("tcp", ":1080")
    if err != nil {
        fmt.Printf("bind error\n")
        return
    }
    for {
        conn, err := ln.Accept()
        if err != nil {
            fmt.Printf("accept error\n")
            continue
        }
        go ProxyConn(conn)
    }
}
