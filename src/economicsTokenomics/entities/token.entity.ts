// economicsTokenomics/entities/token.entity.ts
import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from "typeorm";

@Entity("tokens")
export class Token {
  @PrimaryGeneratedColumn("uuid")
  id: string;

  @Column({ unique: true })
  symbol: string;

  @Column()
  name: string;

  @Column("decimal", { precision: 36, scale: 18 })
  totalSupply: string;

  @Column("decimal", { precision: 36, scale: 18 })
  circulatingSupply: string;

  @Column("decimal", { precision: 36, scale: 18 })
  burnedAmount: string;

  @Column()
  contractAddress: string;

  @Column({ default: 18 })
  decimals: number;

  @Column({ default: true })
  isActive: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
