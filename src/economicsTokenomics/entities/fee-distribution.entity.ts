// economicsTokenomics/entities/fee-distribution.entity.ts
import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
} from "typeorm";

@Entity("fee_distributions")
export class FeeDistribution {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column("decimal", { precision: 36, scale: 18 })
  totalFees: string;

  @Column("decimal", { precision: 36, scale: 18 })
  stakingRewards: string;

  @Column("decimal", { precision: 36, scale: 18 })
  liquidityRewards: string;

  @Column("decimal", { precision: 36, scale: 18 })
  burnAmount: string;

  @Column("decimal", { precision: 36, scale: 18 })
  treasuryAmount: string;

  @Column()
  transactionHash: string;

  @CreateDateColumn()
  createdAt: Date;
}