class "Incrementer"
{
    func "Increment": none_t(int_t "value");
    func "Result": int_t();

    connector = ({
        client = {
            "json_protocol_encode";
            "tcp_connector_master";
            "localhost";
            9898;
        },
        server = {
            "tcp_connector_slave";
            "localhost";
            9898;
            "json_protocol_decode";
            "plain_factory";
        }
    })[target]
}

if target == "client" then
    exports.masters = { Incrementer }
elseif target == "server" then
    exports.slaves  = { Incrementer }
end
