// economicsTokenomics/entities/reward-distribution.entity.ts
import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
} from "typeorm";

@Entity("reward_distributions")
export class RewardDistribution {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column()
  recipient: string;

  @Column("decimal", { precision: 36, scale: 18 })
  amount: string;

  @Column()
  rewardType: string; // staking, liquidity, governance, etc.

  @Column()
  poolId: string;

  @Column()
  transactionHash: string;

  @Column({ default: false })
  claimed: boolean;

  @CreateDateColumn()
  createdAt: Date;
}
