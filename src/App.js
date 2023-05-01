// src/app.js
import "./App.css";
import { ethers } from "ethers";
import { useEffect, useState } from "react";
import TokenArtifact from "./ICO.json";
const tokenAddress = "0x1613beB3B2C4f22Ee086B2b38C1476A3cE7f78E8";

function App() {
  const [tokenData, setTokenData] = useState("");
  const [contract, setContract] = useState();
  const [balance, setBalance] = useState(0);
  const [walletAddress, setWalletAddress] = useState();
  const [saleStatus, setSaleStatus] = useState("false");
  var now = Math.round(+new Date(Date.now() + 1000 * 120).getTime() / 1000);

  const [acceptToken, setacceptToken] = useState([]);

  async function requestAccount() {
    await window.ethereum.request({ method: "eth_requestAccounts" });
  }

  const provider = new ethers.providers.Web3Provider(window.ethereum);
  const signer = provider.getSigner();
  async function _intializeContract() {
    // We first initialize ethers by creating a provider using window.ethereum
    // When, we initialize the contract using that provider and the token's
    // artifact. You can do this same thing with your contracts.
    const contract = new ethers.Contract(
      tokenAddress,
      TokenArtifact.abi,
      signer
    );
    const [account] = await window.ethereum.request({
      method: "eth_requestAccounts",
    });
    setWalletAddress(account);
    setContract(contract);
    const isSaleLive = await contract.isSaleLive();
    const acceptToken = await contract.acceptToken();
    setSaleStatus(isSaleLive);
    setTokenData(acceptToken);
    return contract;
  }

  const buyToken = async () => {
    // get sell info
    const sellInfo = await contract.buyToken(2, { from: walletAddress,gasLimit: 5000000 });
    // const acceptToken = await contract.acceptToken();
    console.log(sellInfo);
  };
  const initiateSale = async () => {

    const sellInfo = await contract.initiateSale(
      10,
      now,
      1714498200,
      1,
      10,
      100,
      false
    );
    console.log(sellInfo);
  };
  const startSale = async () => {
    const resp = await contract.startSale();
    console.log(resp);
    // setSaleStatus(resp)
  };

  useEffect(() => {
    _intializeContract();
  }, []);

  async function getBalance() {
    if (typeof window.ethereum !== "undefined") {
      const balance = await contract.isSaleLive();
      const acceptToken = await contract.acceptToken();
      const saleInfos = await contract.saleInfos();

      console.log("Account Balance: ", balance, saleInfos);
      setBalance(balance.toString());
    }
  }
  return (
    <div className="App">
      <header className="App-header">
        {/* <button onClick={_getTokenData}>get token data</button> */}
        <h7>metamask wallet address: {walletAddress}</h7>
        <h7>token being sold : {tokenData}</h7>
        <h7>Is sale live: {saleStatus.toString()}</h7>

        <button onClick={buyToken}>Buy token</button>
        <button onClick={initiateSale}>initiate sale</button>
        <button onClick={startSale}>start sale</button>
        <button onClick={async()=>{
          setSaleStatus(await contract.endSale())
        }} >End Sale</button>


        <br/>

        <p>now: {new Date(now*1000).toString()},{now}</p>
        {/* <button onClick={sendMDToken}>Send MDToken</button> */}
        {/* <input onChange={e => setUserAccountId(e.target.value)} placeholder="Account ID" />
        <input onChange={e => setAmount(e.target.value)} placeholder="Amount" /> */}
      </header>
    </div>
  );
}
export default App;
