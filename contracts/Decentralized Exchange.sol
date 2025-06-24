// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract Project {
    // State variables
    mapping(address => mapping(address => uint256)) public liquidity;
    mapping(address => uint256) public totalLiquidity;
    address public owner;
    uint256 public constant FEE_PERCENT = 3; // 0.3% trading fee
    
    // Events
    event LiquidityAdded(address indexed token, uint256 amount, address indexed provider);
    event TokensSwapped(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut, address indexed trader);
    event LiquidityRemoved(address indexed token, uint256 amount, address indexed provider);
    
    constructor() {
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }
    
    /**
     * @dev Core Function 1: Add liquidity to the DEX
     * @param token The ERC20 token address
     * @param amount The amount of tokens to add as liquidity
     */
    function addLiquidity(address token, uint256 amount) external {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than 0");
        
        IERC20 tokenContract = IERC20(token);
        require(tokenContract.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        liquidity[msg.sender][token] += amount;
        totalLiquidity[token] += amount;
        
        emit LiquidityAdded(token, amount, msg.sender);
    }
    
    /**
     * @dev Core Function 2: Swap tokens using automated market maker logic
     * @param tokenIn The token being sold
     * @param tokenOut The token being bought
     * @param amountIn The amount of tokenIn to swap
     */
    function swapTokens(address tokenIn, address tokenOut, uint256 amountIn) external {
        require(tokenIn != address(0) && tokenOut != address(0), "Invalid token addresses");
        require(tokenIn != tokenOut, "Cannot swap same token");
        require(amountIn > 0, "Amount must be greater than 0");
        require(totalLiquidity[tokenIn] > 0 && totalLiquidity[tokenOut] > 0, "Insufficient liquidity");
        
        // Simple AMM formula: amountOut = (amountIn * liquidityOut) / (liquidityIn + amountIn)
        // Apply trading fee
        uint256 amountInAfterFee = amountIn * (1000 - FEE_PERCENT) / 1000;
        uint256 amountOut = (amountInAfterFee * totalLiquidity[tokenOut]) / (totalLiquidity[tokenIn] + amountInAfterFee);
        
        require(amountOut > 0, "Insufficient output amount");
        require(amountOut <= totalLiquidity[tokenOut], "Insufficient liquidity for swap");
        
        // Execute the swap
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(msg.sender, amountOut);
        
        // Update liquidity pools
        totalLiquidity[tokenIn] += amountIn;
        totalLiquidity[tokenOut] -= amountOut;
        
        emit TokensSwapped(tokenIn, tokenOut, amountIn, amountOut, msg.sender);
    }
    
    /**
     * @dev Core Function 3: Remove liquidity from the DEX
     * @param token The ERC20 token address
     * @param amount The amount of liquidity to remove
     */
    function removeLiquidity(address token, uint256 amount) external {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than 0");
        require(liquidity[msg.sender][token] >= amount, "Insufficient liquidity balance");
        
        liquidity[msg.sender][token] -= amount;
        totalLiquidity[token] -= amount;
        
        IERC20(token).transfer(msg.sender, amount);
        
        emit LiquidityRemoved(token, amount, msg.sender);
    }
    
    // View functions
    function getLiquidityBalance(address provider, address token) external view returns (uint256) {
        return liquidity[provider][token];
    }
    
    function getTotalLiquidity(address token) external view returns (uint256) {
        return totalLiquidity[token];
    }
    
    function getSwapQuote(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256) {
        require(totalLiquidity[tokenIn] > 0 && totalLiquidity[tokenOut] > 0, "Insufficient liquidity");
        
        uint256 amountInAfterFee = amountIn * (1000 - FEE_PERCENT) / 1000;
        return (amountInAfterFee * totalLiquidity[tokenOut]) / (totalLiquidity[tokenIn] + amountInAfterFee);
    }
    
    // Emergency function - only owner
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner, amount);
    }
}
