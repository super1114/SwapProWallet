//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDEXFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IDEXRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function getAmountsIn(
        uint256 amountOut,
        address[] calldata path
    ) external pure returns(uint256[] memory);

    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external pure returns(uint256[] memory);
}

interface ISwapPro {
    function approveBUSD() external;
}

contract SwapPro is ISwapPro, Ownable {
    address public constant  BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    //address public constant  BUSD = 0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7;
    address public constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;// 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;
    
    address public singer1 = 0x02a3A4dFEe9093b1f0c766843bDe6F6e3481f0AE;
    address public singer2 = 0x1403678F7643352554902BA4Db73EdF737790639;

    address prevSigner;
    address token;
    uint256 amount;
    address to;
    bool isBNB;
    uint8 status; // 1 => pending, 2 => approved, 3=> rejected;

    IDEXRouter router;
    uint256 prevBUSD;
    uint256 prevBNB;
    uint256 minProfit;


    constructor () {
        router = IDEXRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    }

    modifier onlyOwners() {
        require(msg.sender==singer1||msg.sender==singer2);
        _;
    }
    function approveBUSD() external override {
        IERC20(BUSD).approve(address(router), 10000000*10**18);
    }

    function firstApprove() external {
        ISwapPro(address(this)).approveBUSD();
    }

    function swap (bool _bnb) public onlyOwners {
        if(_bnb) {
            prevBNB = address(this).balance;
            address[] memory path = new address[](2);
            path[0] = WBNB;
            path[1] = BUSD;
            uint256 bnbBal = address(this).balance;
            router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: bnbBal}(
                0,
                path,
                address(this),
                block.timestamp
            );
        } else {
            prevBUSD = IERC20(BUSD).balanceOf(address(this));
            address[] memory path = new address[](2);
            path[0] = BUSD;
            path[1] = WBNB;
            router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                IERC20(BUSD).balanceOf(address(this)),
                0,
                path,
                address(this),
                block.timestamp
            );
        }
    }

    function getProfit() public view returns(bool, uint256) {
        if(getAmountsOutBUSD() > prevBUSD) return (true, getAmountsOutBUSD() - prevBUSD);
        else return (false, prevBUSD - getAmountsOutBUSD());
    }

    function getAmountsOutBNB() public view returns(uint256) {
        uint256 busdBal = IERC20(BUSD).balanceOf(address(this));
        if(busdBal == 0) return 0;
        address[] memory path = new address[](2);
        path[0] = BUSD;
        path[1] = WBNB;
        return router.getAmountsOut(busdBal, path)[1];
    }

    function getAmountsOutBUSD() public view returns(uint256) {
        uint256 bnbBal = address(this).balance;
        if(bnbBal == 0) return 0;
        address[] memory path = new address[](2);
        path[0] = WBNB;
        path[1] = BUSD;
        return router.getAmountsOut(bnbBal, path)[1];
    }

    function requestTokenTransaction(address _token, uint256 _amount, address _to) public onlyOwners {
        require(status!=1, "Current transaction is not approved or rejected");
        require(exists(_token)==true, "this is not token address");
        require(IERC20(_token).balanceOf(address(this))>=_amount, "Insufficient balance");
        prevSigner = msg.sender;
        token = _token;
        amount = _amount;
        to = _to;
        isBNB = false;
        status = 1;
    }
    function requestBNBTransaction(uint256 _amount, address _to) public onlyOwners {
        require(status!=1, "Current transaction is not approved or rejected");
        prevSigner = msg.sender;
        token = address(0);
        amount = _amount;
        to = _to;
        isBNB = true;
        status = 1;
    }
    function approveTransaction() public onlyOwners {
        require(prevSigner!=msg.sender, "You are first signer for this transaction");
        require(status==1, "This transaction was already approved or rejected (there is no requested transaction)");
        if(isBNB==true) {
            payable(to).transfer(amount);
        }else {
            IERC20(token).transfer(to, amount);
        }
        
        status = 2;
    }
    function rejectTransaction() public onlyOwners {
        require(status==1, "This transaction was already approved or rejected (there is no requested transaction)");
        status = 3;
    }

    function exists(address what)
        internal
        view
        returns (bool)
    {
        uint size;
        assembly {
            size := extcodesize(what)
        }
        return size > 0;
    }

    function getCurrentTranscaction() public view returns(address _prevSigner, address _token, uint256 _amount, address _to, uint8 _status, bool _isBNB) {
        return (prevSigner, token, amount, to, status, isBNB);
    }
    receive() external payable { }
}