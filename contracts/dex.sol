pragma solidity >= 0.6.0 <= 0.8.0;
pragma experimental ABIEncoderV2;

import "./wallet.sol";
contract Dex is Wallet {
    using SafeMath for uint256;
    enum Side{
        BUY, 
        SELL
    }

    struct Order {
        uint id;
        address trader;
        Side side;
        bytes32 ticker;
        uint amount;
        uint price;
        uint filled;
    }

    uint public nextOrderId=0;

    mapping(bytes32 => mapping(uint => Order[])) public orderBook;

    function getOrderBook(bytes32 ticker, Side side) view public returns(Order[] memory){
        return orderBook[ticker][uint(side)];
    }
    
    function createLimitOrder(Side side, bytes32 ticker, uint amount, uint price) public{
        if(side == Side.BUY){
            require(balances[msg.sender]["ETH"]>= amount.mul(price));
        }else if(side == Side.SELL){
            require(balances[msg.sender][ticker]> amount);
        }

        Order[] storage orders = orderBook[ticker][uint(side)];
        orders.push(Order(nextOrderId,msg.sender,side,ticker,amount,price,0));

        //bubblesort
        uint i = orders.length >0 ? orders.length-1:0;

        if(side==Side.BUY){
            //highest to lowest
            while(i>0){
                if(orders[i-1].price > orders[i].price){
                    break;
                }
                Order memory temp = orders[i-1];
                orders[i-1]=orders[i];
                orders[i]=temp;
                i--;
            }
            
        }else if(side==Side.SELL){
            while(i>0){
                if(orders[i-1].price < orders[i].price){
                    break;
                }
                Order memory temp = orders[i-1];
                orders[i-1]=orders[i];
                orders[i]=temp;
                i--;
            }
        }
        nextOrderId++;
    }
    function createMarketOrder(Side side, bytes32 ticker, uint amount) public{
        if(side==Side.SELL){
            require(balances[msg.sender][ticker] >=amount, "Insufficient balance");
        }
        uint orderBookSide = 0; //default to sell (looking for BUY)
        if(side == Side.BUY){
            orderBookSide=1;
        }
        Order[] storage orders = orderBook[ticker][orderBookSide];

        uint totalFilled;
        
        for (uint256 i=0; i< orders.length && totalFilled < amount; i++ ){
            //how much we can fill from order[i]
            uint leftToFill = amount.sub(totalFilled);//100
            uint availableToFill = orders[i].amount.sub(orders[i].filled); //200
            uint filled =0;
            if(availableToFill>leftToFill){
                filled = leftToFill; //fills the entire market order
            }else{
                filled = availableToFill; //fills as much as available in order[i]
            }
            //update totalFilled;
            totalFilled=totalFilled.add(filled);
            orders[i].filled = orders[i].filled.add(filled);
            uint cost = filled.mul(orders[i].price);
            if(side ==Side.BUY){
                //verify that the buyer has enough eth to cover the trade
                require(balances[msg.sender]["ETH"] > cost);
                //msg.sender is the buyer
                balances[msg.sender][ticker] = balances[msg.sender][ticker].add(filled);
                balances[msg.sender]["ETH"] = balances[msg.sender]["ETH"].sub(cost);
                //Execute the trade (update balances); //transfer ETH from BUYR to Seller 
                //and transfer token from Seller to Buyer
                balances[orders[i].trader][ticker] = balances[orders[i].trader][ticker].sub(filled);
                balances[orders[i].trader]["ETH"] = balances[orders[i].trader]["ETH"].add(cost);
            }else{
                //msg.sender is the seller
                balances[msg.sender][ticker] = balances[msg.sender][ticker].sub(filled);
                balances[msg.sender]["ETH"] = balances[msg.sender]["ETH"].add(cost);

                balances[orders[i].trader][ticker] = balances[orders[i].trader][ticker].add(filled);
                balances[orders[i].trader]["ETH"] = balances[orders[i].trader]["ETH"].sub(cost);
                //Execute the trade (update balances); //transfer ETH from Seller to buyer
                //and transfer token from Buyer to Seller

            }
            
            
        }
        //loop through the order book and remove 100% filled orders
        //overwrite with next element
        while( orders.length>0 && orders[0].filled == orders[0].amount){
            for(uint i=0; i<orders.length-1; i++){
                orders[i]=orders[i+1];
            }
            orders.pop();
        }
    }
}