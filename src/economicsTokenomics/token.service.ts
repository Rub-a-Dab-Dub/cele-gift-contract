// economicsTokenomics/token.service.ts
import { Injectable } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { Token } from "./entities/token.entity";
import { ethers } from "ethers";

@Injectable()
export class TokenService {
  constructor(
    @InjectRepository(Token)
    private tokenRepository: Repository<Token>
  ) {}

  async initializeCGIFTToken() {
    const existingToken = await this.tokenRepository.findOne({
      where: { symbol: "CGIFT" },
    });

    if (!existingToken) {
      const token = this.tokenRepository.create({
        symbol: "CGIFT",
        name: "CeleGift Token",
        totalSupply: "1000000000", // 1 billion tokens
        circulatingSupply: "500000000", // 500 million in circulation
        burnedAmount: "0",
        contractAddress:
          "0x" +
          ethers.utils
            .keccak256(ethers.utils.toUtf8Bytes("CGIFT"))
            .substr(2, 40),
        decimals: 18,
        isActive: true,
      });

      await this.tokenRepository.save(token);
      return token;
    }

    return existingToken;
  }

  async getTokenMetrics() {
    const token = await this.tokenRepository.findOne({
      where: { symbol: "CGIFT" },
    });

    if (!token) {
      return this.initializeCGIFTToken();
    }

    const totalSupply = ethers.utils.parseEther(token.totalSupply);
    const circulatingSupply = ethers.utils.parseEther(token.circulatingSupply);
    const burnedAmount = ethers.utils.parseEther(token.burnedAmount);

    return {
      ...token,
      metrics: {
        totalSupply: token.totalSupply,
        circulatingSupply: token.circulatingSupply,
        burnedAmount: token.burnedAmount,
        burnPercentage: totalSupply.gt(0)
          ? burnedAmount.mul(100).div(totalSupply).toString()
          : "0",
        circulationPercentage: totalSupply.gt(0)
          ? circulatingSupply.mul(100).div(totalSupply).toString()
          : "0",
      },
    };
  }
}
