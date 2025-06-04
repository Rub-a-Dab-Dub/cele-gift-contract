// economicsTokenomics/entities/token-burn.entity.ts
import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
} from "typeorm";

@Entity("token_burns")
export class TokenBurn {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column("decimal", { precision: 36, scale: 18 })
  amount: string;

  @Column()
  reason: string; // fee burn, deflationary burn, etc.

  @Column()
  transactionHash: string;

  @Column()
  burnedBy: string;

  @CreateDateColumn()
  createdAt: Date;
}
